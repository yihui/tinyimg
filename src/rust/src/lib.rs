use extendr_api::prelude::*;
use oxipng::{InFile, OutFile, Options, StripChunks};
use std::path::PathBuf;

/// Optimize a PNG file using oxipng
///
/// @param input Path to input PNG file
/// @param output Path to output PNG file
/// @param level Optimization level (0-6)
/// @param alpha Optimize transparent pixels (may be lossy but visually lossless)
/// @param preserve Preserve file permissions and timestamps
/// @param verbose Print file size reduction info
/// @export
#[extendr]
fn optim_png_impl(
    input: &str,
    output: &str,
    level: i32,
    alpha: bool,
    preserve: bool,
    verbose: bool,
) -> Result<()> {
    // Convert paths
    let input_path = PathBuf::from(input);
    let output_path = PathBuf::from(output);
    
    // Get input file size for reporting
    let input_size = std::fs::metadata(&input_path)
        .map(|m| m.len())
        .unwrap_or(0);
    
    // Set up oxipng options from preset
    let mut opts = Options::from_preset(level as u8);
    
    // Strip all metadata by default
    opts.strip = StripChunks::All;
    
    // Configure alpha optimization
    opts.optimize_alpha = alpha;
    
    // Run optimization
    let in_file = InFile::Path(input_path);
    let out_file = OutFile::Path {
        path: Some(output_path.clone()),
        preserve_attrs: preserve,
    };
    
    match oxipng::optimize(&in_file, &out_file, &opts) {
        Ok(_) => {
            // Get output file size for reporting
            if verbose {
                let output_size = std::fs::metadata(&output_path)
                    .map(|m| m.len())
                    .unwrap_or(0);
                
                if input_size > 0 {
                    let reduction = ((input_size as f64 - output_size as f64) / input_size as f64) * 100.0;
                    rprintln!(
                        "  {} | {} -> {} ({:.1}%)",
                        output_path.display(),
                        format_bytes(input_size),
                        format_bytes(output_size),
                        reduction
                    );
                }
            }
            Ok(())
        },
        Err(e) => Err(format!("Failed to optimize PNG: {}", e).into()),
    }
}

/// Format bytes in human-readable form (similar to xfun::format_bytes)
fn format_bytes(bytes: u64) -> String {
    const UNITS: &[&str] = &["B", "KB", "MB", "GB", "TB"];
    
    if bytes == 0 {
        return "0 B".to_string();
    }
    
    let mut size = bytes as f64;
    let mut unit_index = 0;
    
    while size >= 1024.0 && unit_index < UNITS.len() - 1 {
        size /= 1024.0;
        unit_index += 1;
    }
    
    if unit_index == 0 {
        format!("{} {}", bytes, UNITS[unit_index])
    } else {
        format!("{:.1} {}", size, UNITS[unit_index])
    }
}

// Macro to generate exports
extendr_module! {
    mod tinyimg;
    fn optim_png_impl;
}
