use extendr_api::prelude::*;
use oxipng::{InFile, OutFile, Options, StripChunks};
use std::path::PathBuf;

/// Optimize a PNG file using oxipng
///
/// @param input Path to input PNG file
/// @param output Path to output PNG file
/// @param level Optimization level (0-6)
/// @param alpha Optimize transparent pixels (may be lossy but visually lossless)
/// @param fast Use fast compression evaluation
/// @param preserve Preserve file permissions and timestamps
/// @export
#[extendr]
fn optim_png_impl(
    input: &str,
    output: &str,
    level: i32,
    alpha: bool,
    fast: bool,
    preserve: bool,
) -> Result<()> {
    // Convert paths
    let input_path = PathBuf::from(input);
    let output_path = PathBuf::from(output);
    
    // Set up oxipng options from preset
    let mut opts = Options::from_preset(level as u8);
    
    // Strip all metadata by default
    opts.strip = StripChunks::All;
    
    // Configure alpha optimization
    opts.optimize_alpha = alpha;
    
    // Configure fast mode
    opts.fast_evaluation = fast;
    
    // Run optimization
    let in_file = InFile::Path(input_path);
    let out_file = OutFile::Path {
        path: Some(output_path),
        preserve_attrs: preserve,
    };
    
    match oxipng::optimize(&in_file, &out_file, &opts) {
        Ok(_) => Ok(()),
        Err(e) => Err(format!("Failed to optimize PNG: {}", e).into()),
    }
}

// Macro to generate exports
extendr_module! {
    mod tinyimg;
    fn optim_png_impl;
}
