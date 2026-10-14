//
//  Kokoro-tts-lib
//
import Foundation
import MLX
import MLXNN

/// Conv1d whose weight normalization is already folded into `weight` (tools/kokoro/build_assets.py).
class ConvWeighted: Module {
  var weight: MLXArray
  var bias: MLXArray?

  let stride: Int
  let padding: Int
  let dilation: Int
  let outputPadding: Int
  let groups: Int

  init(
    weight: MLXArray,
    bias: MLXArray?,
    stride: Int = 1,
    padding: Int = 1,
    dilation: Int = 1,
    outputPadding: Int = 0,
    groups: Int = 1
  ) {
    self.stride = stride
    self.padding = padding
    self.dilation = dilation
    self.outputPadding = outputPadding
    self.groups = groups

    self.weight = weight
    self.bias = bias

    super.init()
  }
  
  public func callAsFunction(_ x: MLXArray, conv: (MLXArray, MLXArray, Int, Int, Int, Int, StreamOrDevice) -> MLXArray) -> MLXArray {
    bias = bias?.reshaped([1, 1, -1])

    func applyConv(x: MLXArray, weightToUse: MLXArray) -> MLXArray {
      let result = conv(
        x,
        weightToUse,
        self.stride,
        padding,
        dilation,
        groups,
        .default
      )

      if let bias = bias {
        return result + bias
      }
      return result
    }

    if x.shape.last == weight.shape.last || groups > 1 {
      return applyConv(x: x, weightToUse: weight)
    } else {
      return applyConv(x: x, weightToUse: weight.transposed())
    }
  }
  
  public func callAsFunction(_ x: MLXArray, conv: (MLXArray, MLXArray, Int, Int, Int, Int, Int, StreamOrDevice) -> MLXArray) -> MLXArray {
    bias = bias?.reshaped([1, 1, -1])

    func applyConv(x: MLXArray, weightToUse: MLXArray) -> MLXArray {
      let result = conv(
        x,
        weightToUse,
        self.stride,
        padding,
        dilation,
        outputPadding,
        groups,
        .default
      )

      if let bias = bias {
        return result + bias
      }
      return result
    }

    if x.shape.last == weight.shape.last || groups > 1 {
      return applyConv(x: x, weightToUse: weight)
    } else {
      return applyConv(x: x, weightToUse: weight.transposed())
    }
  }
}
