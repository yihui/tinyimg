use extendr_api::prelude::*;
use exoquant::{convert_to_indexed, ditherer, optimizer, Color};
use oxipng::{InFile, OutFile, Options, StripChunks};
use std::collections::{HashMap, HashSet};
use std::path::PathBuf;

/// Optimize PNG files using oxipng
///
/// @param input Vector of input PNG file paths
/// @param output Vector of output PNG file paths (same length as input)
/// @param level Optimization level (0-6)
/// @param alpha Optimize transparent pixels (may be lossy but visually lossless)
/// @param preserve Preserve file permissions and timestamps
/// @param verbose Print file size reduction info
/// @param lossy Maximum CIE76 Delta E threshold
/// @export
#[extendr]
fn tinypng_impl(
    input: Strings,
    output: Strings,
    level: i32,
    alpha: bool,
    preserve: bool,
    verbose: bool,
    lossy: f64,
) -> Result<()> {
    // Convert to vectors
    let inputs: Vec<String> = input.iter().map(|s| s.to_string()).collect();
    let outputs: Vec<String> = output.iter().map(|s| s.to_string()).collect();

    // Validate that input and output have same length
    if inputs.len() != outputs.len() {
        return Err("Input and output vectors must have the same length".into());
    }

    // Check all input files exist before processing any
    for input_str in &inputs {
        let input_path = PathBuf::from(input_str);
        if !input_path.exists() {
            return Err(format!("Input file does not exist: {}", input_str).into());
        }
    }

    // Create output directories if needed
    for output_str in &outputs {
        let output_path = PathBuf::from(output_str);
        if let Some(parent) = output_path.parent() {
            if !parent.exists() {
                std::fs::create_dir_all(parent)
                    .map_err(|e| format!("Failed to create directory {}: {}", parent.display(), e))?;
            }
        }
    }

    // Set up oxipng options from preset
    let mut opts = Options::from_preset(level as u8);

    // Strip all metadata by default
    opts.strip = StripChunks::All;

    // Configure alpha optimization
    opts.optimize_alpha = alpha;

    // Find common parent directories for display
    let input_truncate_index = if verbose { find_truncate_index(&inputs) } else { 0 };
    let output_truncate_index = if verbose { find_truncate_index(&outputs) } else { 0 };

    // Process each file
    for (input_str, output_str) in inputs.iter().zip(outputs.iter()) {
        let input_path = PathBuf::from(input_str);
        let output_path = PathBuf::from(output_str);

        // Get input file size for reporting
        let input_size = std::fs::metadata(&input_path)
            .map(|m| m.len())
            .unwrap_or(0);

        // Optional lossy preprocessing before lossless optimization
        match if lossy > 0.0 {
            let lossy_data = apply_lossy_png(&input_path, lossy)?;
            let optimized_data = oxipng::optimize_from_memory(&lossy_data, &opts)
                .map_err(|e| format!("Failed to optimize {}: {}", input_path.display(), e))?;
            std::fs::write(&output_path, optimized_data)
                .map_err(|e| format!("Failed to write {}: {}", output_path.display(), e))?;
            Ok(())
        } else {
            let in_file = InFile::Path(input_path.clone());
            let out_file = OutFile::Path {
                path: Some(output_path.clone()),
                preserve_attrs: preserve,
            };
            oxipng::optimize(&in_file, &out_file, &opts)
                .map_err(|e| format!("Failed to optimize {}: {}", input_path.display(), e))
        } {
            Ok(_) => {
                // Get output file size for reporting
                if verbose {
                    let output_size = std::fs::metadata(&output_path)
                        .map(|m| m.len())
                        .unwrap_or(0);

                    if input_size > 0 {
                        let reduction = ((input_size as f64 - output_size as f64) / input_size as f64) * 100.0;
                        let sign = if output_size < input_size { "-" } else { "+" };

                        // Format the display paths
                        let display_input = truncate_path(input_str, input_truncate_index);
                        let display_output = truncate_path(output_str, output_truncate_index);

                        // Build the output message
                        let path_display = if input_str == output_str {
                            display_output
                        } else {
                            format!("{} -> {}", display_input, display_output)
                        };

                        rprintln!(
                            "{} | {} -> {} ({}{:.1}%)",
                            path_display,
                            format_bytes(input_size),
                            format_bytes(output_size),
                            sign,
                            reduction.abs()
                        );
                    }
                }
            },
            Err(e) => {
                return Err(e.into());
            },
        }
    }

    Ok(())
}

fn apply_lossy_png(input: &PathBuf, lossy: f64) -> Result<Vec<u8>> {
    // Decode source image into RGBA pixels used as the ground truth.
    let image = lodepng::decode32_file(input)
        .map_err(|e| format!("Failed to read PNG {}: {}", input.display(), e))?;
    let pixels: Vec<Color> = image
        .buffer
        .iter()
        .map(|p| Color::new(p.r, p.g, p.b, p.a))
        .collect();

    // Sample at most 50k pixels for perceptual error evaluation.
    let sample_idx = sample_indices(pixels.len(), 50_000);
    let src_lab: Vec<[f64; 3]> = sample_idx.iter().map(|&i| to_lab(pixels[i])).collect();

    // Pre-compute RGBA keys for sampled pixels once; reused in every bisection step.
    let sample_keys: Vec<u32> = sample_idx
        .iter()
        .map(|&i| color_key(pixels[i]))
        .collect();

    // Pre-allocate the per-color map; cleared and refilled in each evaluation.
    let mut color_max_de: HashMap<u32, f64> = HashMap::new();

    // Quantize at 256 colors first to establish an upper bound for the bisection.
    // If even 256 colors exceeds the threshold, use 256 (best possible quality).
    // Otherwise the number of distinct colors actually used in the 256-quantized
    // image is a tighter upper bound: there is no benefit searching above it.
    let q256 = quantize_image_nodither(&pixels, image.width, 256);
    let metric256 = palette_p95_delta_e(&src_lab, &sample_keys, &q256, &sample_idx, &mut color_max_de);

    let n = if metric256 > lossy {
        256
    } else {
        let mut lo = 1usize;
        let mut hi = count_unique_colors(&q256).min(256);
        while lo < hi {
            let mid = (lo + hi) / 2;
            let quantized_mid = quantize_image_nodither(&pixels, image.width, mid);
            let metric = palette_p95_delta_e(&src_lab, &sample_keys, &quantized_mid, &sample_idx, &mut color_max_de);
            if metric <= lossy {
                hi = mid;
            } else {
                lo = mid + 1;
            }
        }
        lo
    };

    let quantized = quantize_image(&pixels, image.width, n);

    let encoded: Vec<lodepng::RGBA> = quantized
        .iter()
        .map(|c| lodepng::RGBA::new(c.r, c.g, c.b, c.a))
        .collect();
    lodepng::encode32(&encoded, image.width, image.height)
        .map_err(|e| format!("Failed to encode quantized PNG data: {}", e).into())
}

fn quantize_image(pixels: &[Color], width: usize, n: usize) -> Vec<Color> {
    let (palette, indexed) = convert_to_indexed(
        pixels, width, n.clamp(1, 256), &optimizer::KMeans, &ditherer::Ordered
    );
    indexed.iter().map(|&idx| palette[idx as usize]).collect()
}

fn quantize_image_nodither(pixels: &[Color], width: usize, n: usize) -> Vec<Color> {
    let (palette, indexed) = convert_to_indexed(
        pixels, width, n.clamp(1, 256), &optimizer::KMeans, &ditherer::None
    );
    indexed.iter().map(|&idx| palette[idx as usize]).collect()
}

fn sample_indices(len: usize, max_samples: usize) -> Vec<usize> {
    if len == 0 {
        return Vec::new();
    }
    let step = (len / max_samples).max(1);
    (0..len).step_by(step).collect()
}

#[inline]
fn color_key(c: Color) -> u32 {
    ((c.r as u32) << 24) | ((c.g as u32) << 16) | ((c.b as u32) << 8) | c.a as u32
}

fn count_unique_colors(pixels: &[Color]) -> usize {
    pixels.iter().map(|&c| color_key(c)).collect::<HashSet<u32>>().len()
}

/// Compute the 95th percentile of per-unique-color max DeltaE.
/// Pixels are grouped by their original RGBA color so that a dominant
/// background color gets only a single vote.  Within each group the
/// worst-case DeltaE is kept; then p95 is taken over those group-level values.
///
/// `sample_keys` must be pre-computed from the original pixels (one key per
/// sampled pixel, in the same order as `sample_idx`).  `color_max_de` is a
/// caller-owned map that is cleared and refilled on each call, avoiding a
/// heap allocation per bisection step.
fn palette_p95_delta_e(
    src_lab: &[[f64; 3]],
    sample_keys: &[u32],
    quantized: &[Color],
    sample_idx: &[usize],
    color_max_de: &mut HashMap<u32, f64>,
) -> f64 {
    color_max_de.clear();
    for (j, &i) in sample_idx.iter().enumerate() {
        let de = delta_e(src_lab[j], to_lab(quantized[i]));
        let entry = color_max_de.entry(sample_keys[j]).or_insert(0.0_f64);
        if de > *entry { *entry = de; }
    }
    let mut des: Vec<f64> = color_max_de.values().copied().collect();
    if des.is_empty() { return 0.0; }
    des.sort_by(|a, b| a.partial_cmp(b).unwrap_or(std::cmp::Ordering::Equal));
    let p = ((des.len() as f64 * 0.95).ceil() as usize).saturating_sub(1);
    des[p.min(des.len() - 1)]
}

fn delta_e(a: [f64; 3], b: [f64; 3]) -> f64 {
    let dl = a[0] - b[0];
    let da = a[1] - b[1];
    let db = a[2] - b[2];
    (dl * dl + da * da + db * db).sqrt()
}

fn to_lab(c: Color) -> [f64; 3] {
    // sRGB transfer function constants (IEC 61966-2-1).
    fn lin(u: f64) -> f64 {
        if u > 0.04045 { ((u + 0.055) / 1.055).powf(2.4) } else { u / 12.92 }
    }
    // CIE Lab piecewise transform constants (epsilon, kappa).
    fn f(t: f64) -> f64 {
        if t > 0.008856 { t.powf(1.0 / 3.0) } else { (903.3 * t + 16.0) / 116.0 }
    }
    let r = lin(c.r as f64 / 255.0);
    let g = lin(c.g as f64 / 255.0);
    let b = lin(c.b as f64 / 255.0);
    // sRGB -> XYZ matrix under D65 white point, then white-point normalization.
    let x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / 0.95047;
    let y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b;
    let z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / 1.08883;
    let fx = f(x);
    let fy = f(y);
    let fz = f(z);
    [116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz)]
}

/// Find the index position to truncate paths
/// Returns the position after the last common '/' or '\', or 0 if no truncation needed
fn find_truncate_index(paths: &[String]) -> usize {
    if paths.is_empty() {
        return 0;
    }

    if paths.len() == 1 {
        // For single path, find the last '/' or '\'
        let path = &paths[0];
        if let Some(pos) = path.rfind(|c| c == '/' || c == '\\') {
            return pos + 1;
        }
        return 0;
    }

    // Find the position of the last '/' or '\' in the first path
    let first_path = &paths[0];
    let last_separator = first_path.rfind(|c| c == '/' || c == '\\');

    if last_separator.is_none() {
        return 0;
    }

    let last_sep_pos = last_separator.unwrap();

    // Iterate through positions to find the largest common prefix ending at a separator
    let mut truncate_idx = 0;

    for pos in 0..=last_sep_pos {
        let ch = first_path.chars().nth(pos).unwrap();

        // Check if all paths have the same character at this position
        if paths.iter().all(|p| p.chars().nth(pos) == Some(ch)) {
            // If this is a separator, update our truncate index
            if ch == '/' || ch == '\\' {
                truncate_idx = pos + 1;
            }
        } else {
            // Found a mismatch, return the last valid truncate index
            return truncate_idx;
        }
    }

    truncate_idx
}

/// Truncate a path by removing the first n characters
fn truncate_path(path: &str, index: usize) -> String {
    if index == 0 || index >= path.len() {
        return path.to_string();
    }
    path[index..].to_string()
}

/// Format bytes in human-readable form (similar to xfun::format_bytes)
fn format_bytes(bytes: u64) -> String {
    let units = ["B", "KB", "MB", "GB", "TB", "PB"];
    if bytes == 0 { return "0 B".to_string(); }

    let i = (bytes as f64).log(1024.0).floor() as usize;
    let p = 1024_f64.powi(i as i32);
    let s = (bytes as f64) / p;

    format!("{:.1} {}", s, units[i])
}

// Macro to generate exports
extendr_module! {
    mod tinyimg;
    fn tinypng_impl;
}
