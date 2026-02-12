use extendr_api::prelude::*;
use oxipng::{InFile, OutFile, Options};
use std::path::PathBuf;

/// Optimize a PNG file using oxipng
///
/// @param input Path to input PNG file
/// @param output Path to output PNG file
/// @param level Optimization level (0-6)
/// @export
#[extendr]
fn optim_png_impl(input: &str, output: &str, level: i32) -> Result<()> {
    // Convert paths
    let input_path = PathBuf::from(input);
    let output_path = PathBuf::from(output);
    
    // Set up oxipng options
    let opts = Options::from_preset(level as u8);
    
    // Run optimization
    let in_file = InFile::Path(input_path);
    let out_file = OutFile::Path {
        path: Some(output_path),
        preserve_attrs: true,
    };
    
    match oxipng::optimize(&in_file, &out_file, &opts) {
        Ok(_) => Ok(()),
        Err(e) => Err(format!("Failed to optimize PNG: {}", e).into()),
    }
}

// Macro to generate exports
extendr_module! {
    mod optimg;
    fn optim_png_impl;
}
