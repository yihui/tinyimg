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
    let common_input_prefix = if verbose { find_common_parent(&inputs) } else { String::new() };
    let common_output_prefix = if verbose { find_common_parent(&outputs) } else { String::new() };
    
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
                        let display_input = format_display_path(input_str, &common_input_prefix, inputs.len() == 1);
                        let display_output = format_display_path(output_str, &common_output_prefix, outputs.len() == 1);
                        
                        // Build the output message
                        let message = if input_str == output_str {
                            // Same path, show only once
                            format!(
                                "{} | {} -> {} ({}{:.1}%)",
                                display_output,
                                format_bytes(input_size),
                                format_bytes(output_size),
                                sign,
                                reduction.abs()
                            )
                        } else {
                            // Different paths, show both
                            format!(
                                "{} -> {} | {} -> {} ({}{:.1}%)",
                                display_input,
                                display_output,
                                format_bytes(input_size),
                                format_bytes(output_size),
                                sign,
                                reduction.abs()
                            )
                        };
                        
                        rprintln!("{}", message);
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

/// Find the longest common parent directory of all paths
fn find_common_parent(paths: &[String]) -> String {
    if paths.is_empty() {
        return String::new();
    }
    
    if paths.len() == 1 {
        // For single path, return empty so we use basename
        return String::new();
    }
    
    // Convert all paths to absolute paths for comparison
    let abs_paths: Vec<PathBuf> = paths
        .iter()
        .filter_map(|p| std::fs::canonicalize(p).ok())
        .collect();
    
    if abs_paths.is_empty() || abs_paths.len() != paths.len() {
        return String::new();
    }
    
    // Get parent directories
    let parents: Vec<PathBuf> = abs_paths
        .iter()
        .filter_map(|p| p.parent().map(|parent| parent.to_path_buf()))
        .collect();
    
    if parents.is_empty() {
        return String::new();
    }
    
    // Find common prefix of all parent paths
    let mut common = parents[0].clone();
    
    for parent in &parents[1..] {
        // Find common prefix between common and parent
        common = find_common_prefix(&common, parent);
        if common.as_os_str().is_empty() {
            break;
        }
    }
    
    common.to_string_lossy().to_string()
}

/// Find common prefix between two paths
fn find_common_prefix(path1: &PathBuf, path2: &PathBuf) -> PathBuf {
    let components1: Vec<_> = path1.components().collect();
    let components2: Vec<_> = path2.components().collect();
    
    let mut common = PathBuf::new();
    for (c1, c2) in components1.iter().zip(components2.iter()) {
        if c1 == c2 {
            common.push(c1);
        } else {
            break;
        }
    }
    
    common
}

/// Format a path for display by removing common prefix or using basename
fn format_display_path(path: &str, common_prefix: &str, use_basename: bool) -> String {
    if use_basename {
        // Single path - use basename only
        return PathBuf::from(path)
            .file_name()
            .and_then(|n| n.to_str())
            .unwrap_or(path)
            .to_string();
    }
    
    if common_prefix.is_empty() {
        return path.to_string();
    }
    
    // Try to canonicalize the path for proper prefix removal
    let abs_path = match std::fs::canonicalize(path) {
        Ok(p) => p.to_string_lossy().to_string(),
        Err(_) => path.to_string(),
    };
    
    // Remove common prefix
    if abs_path.starts_with(common_prefix) {
        let mut result = abs_path[common_prefix.len()..].to_string();
        // Remove leading slash if present
        if result.starts_with('/') || result.starts_with('\\') {
            result = result[1..].to_string();
        }
        result
    } else {
        path.to_string()
    }
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
