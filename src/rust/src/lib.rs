use extendr_api::prelude::*;
use oxipng::{InFile, OutFile, Options, StripChunks, Interlacing};
use std::path::PathBuf;
use std::time::Duration;

/// Optimize a PNG file using oxipng
///
/// @param input Path to input PNG file
/// @param output Path to output PNG file
/// @param level Optimization level (0-6)
/// @param strip Strip metadata chunks ("safe", "all", or NULL for none)
/// @param alpha Optimize transparent pixels (may be lossy but visually lossless)
/// @param interlace Interlacing mode ("off", "on", or "keep")
/// @param fast Use fast compression evaluation
/// @param preserve Preserve file permissions and timestamps
/// @param timeout Maximum optimization time in seconds (0 for no limit)
/// @export
#[extendr]
fn optim_png_impl(
    input: &str,
    output: &str,
    level: i32,
    strip: Robj,
    alpha: bool,
    interlace: &str,
    fast: bool,
    preserve: bool,
    timeout: i32,
) -> Result<()> {
    // Convert paths
    let input_path = PathBuf::from(input);
    let output_path = PathBuf::from(output);
    
    // Set up oxipng options from preset
    let mut opts = Options::from_preset(level as u8);
    
    // Configure strip option
    if !strip.is_null() {
        let strip_str = <&str>::try_from(strip)?;
        opts.strip = match strip_str {
            "safe" => StripChunks::Safe,
            "all" => StripChunks::All,
            _ => return Err(format!("Invalid strip mode: {}. Use 'safe' or 'all'", strip_str).into()),
        };
    }
    
    // Configure alpha optimization
    opts.optimize_alpha = alpha;
    
    // Configure interlacing
    opts.interlace = match interlace {
        "off" => Some(Interlacing::None),
        "on" => Some(Interlacing::Adam7),
        "keep" => None,
        _ => return Err(format!("Invalid interlace mode: {}. Use 'off', 'on', or 'keep'", interlace).into()),
    };
    
    // Configure fast mode
    opts.fast_evaluation = fast;
    
    // Configure timeout
    if timeout > 0 {
        opts.timeout = Some(Duration::from_secs(timeout as u64));
    }
    
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
