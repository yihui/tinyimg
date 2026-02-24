use extendr_api::prelude::*;
use exoquant::{convert_to_indexed, ditherer, optimizer, Color};
use oxipng::{InFile, OutFile, Options, StripChunks};
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
fn optim_png_impl(
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
    if !lossy.is_finite() {
        return Err("Lossy must be a finite number".into());
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
    let image = lodepng::decode32_file(input)
        .map_err(|e| format!("Failed to read PNG {}: {}", input.display(), e))?;
    let pixels: Vec<Color> = image
        .buffer
        .iter()
        .map(|p| Color::new(p.r, p.g, p.b, p.a))
        .collect();

    // 1) Quantize once at 256 colors.
    let (palette, indexed) = convert_to_indexed(
        &pixels, image.width, 256, &optimizer::KMeans, &ditherer::Ordered
    );

    // 2) Sort palette entries by pixel frequency.
    let mut freq = vec![0usize; palette.len()];
    for &idx in &indexed {
        freq[idx as usize] += 1;
    }
    let mut order: Vec<usize> = (0..palette.len()).collect();
    order.sort_by(|&a, &b| freq[b].cmp(&freq[a]));

    // lossy is used directly as the CIE76 Delta E threshold.
    let max_de = lossy;
    let palette_lab: Vec<[f64; 3]> = palette.iter().map(|c| to_lab(*c)).collect();

    // Find minimal N such that worst palette reconstruction error <= threshold.
    let mut lo = 1usize;
    let mut hi = palette.len().max(1);
    while lo < hi {
        let mid = (lo + hi) / 2;
        let (_, worst) = map_palette(&order, &palette_lab, mid);
        if worst <= max_de {
            hi = mid;
        } else {
            lo = mid + 1;
        }
    }
    let n = lo;

    let (idx_map, _) = map_palette(&order, &palette_lab, n);
    let selected_palette: Vec<Color> = order.iter().take(n).map(|&i| palette[i]).collect();

    let quantized: Vec<lodepng::RGBA> = indexed
        .iter()
        .map(|&idx| {
            let c = selected_palette[idx_map[idx as usize]];
            lodepng::RGBA::new(c.r, c.g, c.b, c.a)
        })
        .collect();
    lodepng::encode32(&quantized, image.width, image.height)
        .map_err(|e| format!("Failed to encode quantized PNG data: {}", e).into())
}

fn map_palette(order: &[usize], palette_lab: &[[f64; 3]], n: usize) -> (Vec<usize>, f64) {
    let selected = &order[..n];
    let mut selected_pos = vec![usize::MAX; palette_lab.len()];
    for (j, &i) in selected.iter().enumerate() {
        selected_pos[i] = j;
    }
    let mut idx_map = vec![0usize; palette_lab.len()];
    let mut worst = 0.0;
    for (i, lab) in palette_lab.iter().enumerate() {
        if selected_pos[i] != usize::MAX {
            idx_map[i] = selected_pos[i];
            continue;
        }
        let mut best_j = 0usize;
        let mut best_d = f64::INFINITY;
        for (j, &k) in selected.iter().enumerate() {
            let d = delta_e(*lab, palette_lab[k]);
            if d < best_d {
                best_d = d;
                best_j = j;
            }
        }
        idx_map[i] = best_j;
        if best_d > worst {
            worst = best_d;
        }
    }
    (idx_map, worst)
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
    fn optim_png_impl;
}
