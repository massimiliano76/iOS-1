import Foundation

func createBorderStyleFactory(from colorFactory: ColorFactory) -> BorderStyleFactory {
    BorderStyleFactoryImpl(colorFactory: colorFactory)
}

enum MEGABorderStyle {
    case inactive
    case warning
}

protocol BorderStyleFactory {

    func borderStyle(of borderStyle: MEGABorderStyle) -> BorderStyle
}

private struct BorderStyleFactoryImpl: BorderStyleFactory {

    let colorFactory: ColorFactory

    func borderStyle(of borderStyle: MEGABorderStyle) -> BorderStyle {
        switch borderStyle {
        case .inactive:
            return BorderStyle(width: 1, color: colorFactory.borderColor(.primary))
        case .warning:
            return BorderStyle(width: 1, color: colorFactory.borderColor(.warning))
        }
    }
}
