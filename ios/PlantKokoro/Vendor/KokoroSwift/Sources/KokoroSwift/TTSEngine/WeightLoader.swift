//
//  Kokoro-tts-lib
//
import Foundation
import MLX
import MLXNN

/// Utility class for loading and preprocessing neural network weights.
///
/// WeightLoader handles the loading of model weights from disk and applies necessary
/// transformations to ensure compatibility with the model architecture. This includes:
/// - Filtering out unnecessary weights (e.g., position_ids)
/// - Transposing weight tensors for specific layers
/// - Validating and processing weight shapes
///
/// The class processes weights for different model components:
/// - BERT encoder weights
/// - Predictor (duration and prosody) weights
/// - Text encoder weights
/// - Decoder weights
final class WeightLoader {
  /// WeightLoader is a utility class with only static methods.
  private init() {}

  /// Loads and sanitizes model weights from the specified path.
  /// This method reads the raw model weights and applies component-specific transformations:
  /// - **BERT weights**: Filters out position_ids (not needed for inference)
  /// - **Predictor weights**: Transposes F0 and N projection weights, handles folded conv weights conditionally
  /// - **Text encoder weights**: Handles folded conv weights with conditional transposition
  /// - **Decoder weights**: Transposes noise convolution weights and handles folded conv weights conditionally
  /// - Parameter modelPath: URL to the directory containing model weight files
  /// - Returns: Dictionary mapping weight names to their processed MLXArray tensors
  /// - Note: Uses forced try (try!) as weight loading is critical and should fail fast if unsuccessful
  static func loadWeights(modelPath: URL) -> [String: MLXArray] {
    // Load raw weights from disk
    let weights = try! MLX.loadArrays(url: modelPath)
    var sanitizedWeights: [String: MLXArray] = [:]

    // Process each weight based on its component prefix
    for (key, value) in weights {
      // Process BERT encoder weights
      if key.hasPrefix("bert") {
        // Skip position_ids as they're not needed for inference
        if key.contains("position_ids") {
          continue
        }
        sanitizedWeights[key] = value
        
      // Process predictor (duration and prosody) weights
      } else if key.hasPrefix("predictor") {
        // F0 projection weights need transposition for proper matrix multiplication
        if key.contains("F0_proj.weight") {
          sanitizedWeights[key] = value.transposed(0, 2, 1)
          
        // N (noise) projection weights need transposition
        } else if key.contains("N_proj.weight") {
          sanitizedWeights[key] = value.transposed(0, 2, 1)
          
        // Folded weight-norm conv weights need conditional transposition
        } else if isFoldedConvWeight(key, value) {
          if checkArrayShape(arr: value) {
            sanitizedWeights[key] = value
          } else {
            sanitizedWeights[key] = value.transposed(0, 2, 1)
          }
        } else {
          sanitizedWeights[key] = value
        }
        
      // Process text encoder weights
      } else if key.hasPrefix("text_encoder") {
        // Folded weight-norm conv weights need conditional transposition
        if isFoldedConvWeight(key, value) {
          if checkArrayShape(arr: value) {
            sanitizedWeights[key] = value
          } else {
            sanitizedWeights[key] = value.transposed(0, 2, 1)
          }
        } else {
          sanitizedWeights[key] = value
        }
        
      // Process decoder weights
      } else if key.hasPrefix("decoder") {
        // Noise convolution weights need transposition
        if key.contains("noise_convs"), key.hasSuffix(".weight") {
          sanitizedWeights[key] = value.transposed(0, 2, 1)
          
        // Folded weight-norm conv weights need conditional transposition
        } else if isFoldedConvWeight(key, value) {
          if checkArrayShape(arr: value) {
            sanitizedWeights[key] = value
          } else {
            sanitizedWeights[key] = value.transposed(0, 2, 1)
          }
        } else {
          sanitizedWeights[key] = value
        }
      }
    }

    return sanitizedWeights
  }

  /// A weight-normalized conv. The build script folds `weight_g` / `weight_v` into one `weight` of
  /// `weight_v`'s shape, so the same transposition rule applies. The only other 3-D `.weight`s
  /// (F0/N projections, noise convs) are matched by the branches before this one.
  private static func isFoldedConvWeight(_ key: String, _ value: MLXArray) -> Bool {
    key.hasSuffix(".weight") && value.ndim == 3
  }

  /// Checks if a 3D weight array has the correct shape and doesn't need transposition.
  /// This method validates whether a weight tensor is already in the correct format
  /// by checking its dimensions. The criteria for a valid shape are:
  /// - The array must have 3 dimensions
  /// - Output channels should be >= kernel height and width
  /// - Kernel height and width should be equal (square kernel)
  /// - Parameter arr: The MLXArray to check
  /// - Returns: `true` if the array has the correct shape and doesn't need transposition,
  ///            `false` if it needs to be transposed
  /// - Note: Returns `false` immediately if the array doesn't have exactly 3 dimensions
  private static func checkArrayShape(arr: MLXArray) -> Bool {
    // Must be 3D array (out_channels, kernel_height, kernel_width)
    guard arr.shape.count == 3 else { return false }

    let outChannels = arr.shape[0]
    let kH = arr.shape[1]  // kernel height
    let kW = arr.shape[2]  // kernel width

    // Check if dimensions are in the expected order:
    // - Output channels should be larger than kernel dimensions
    // - Kernel should be square (height == width)
    return (outChannels >= kH) && (outChannels >= kW) && (kH == kW)
  }
}
