use extendr_api::prelude::*;
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
/// @export
#[extendr]
fn optim_png_impl(
    input: Strings,
    output: Strings,
    level: i32,
    alpha: bool,
    preserve: bool,
    verbose: bool,
) -> Result<()> {
    // Convert to vectors
    let inputs: Vec<String> = input.into_iter().collect();
    let outputs: Vec<String> = output.into_iter().collect();
    
    // Validate that input and output have same length
    if inputs.len() != outputs.len() {
        return Err("Input and output vectors must have the same length".into());
    }
    
    // Set up oxipng options from preset
    let mut opts = Options::from_preset(level as u8);
    
    // Strip all metadata by default
    opts.strip = StripChunks::All;
    
    // Configure alpha optimization
    opts.optimize_alpha = alpha;
    
    // Process each file
    for (input_str, output_str) in inputs.iter().zip(outputs.iter()) {
        let input_path = PathBuf::from(input_str);
        let output_path = PathBuf::from(output_str);
        
        // Get input file size for reporting
        let input_size = std::fs::metadata(&input_path)
            .map(|m| m.len())
            .unwrap_or(0);
        
        // Run optimization
        let in_file = InFile::Path(input_path.clone());
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
            },
            Err(e) => {
                return Err(format!("Failed to optimize {}: {}", input_path.display(), e).into());
            },
        }
    }
    
    Ok(())
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
