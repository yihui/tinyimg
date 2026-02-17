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
                return Err(format!("Failed to optimize {}: {}", input_path.display(), e).into());
            },
        }
    }
    
    Ok(())
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
