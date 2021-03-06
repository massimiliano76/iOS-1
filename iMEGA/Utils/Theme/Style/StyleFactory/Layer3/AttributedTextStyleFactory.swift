import Foundation

extension InterfaceStyle {

    var attributedTextStyleFactory: AttributedTextStyleFactory {
        return AttributedTextStyleFactoryImpl(textStyleFactory: textStyleFactory,
                                              paragraphStyleFactory: paragraphStyleFactory)
    }
}

protocol AttributedTextStyleFactory {

    func styler(of textStyle: AttributedTextStyle) -> AttributedTextStyler
}

private struct AttributedTextStyleFactoryImpl: AttributedTextStyleFactory {

    let textStyleFactory: TextStyleFactory

    let paragraphStyleFactory: ParagraphStyleFactory

    func styler(of textStyle: AttributedTextStyle) -> AttributedTextStyler {
        let textStyleFactory = self.textStyleFactory
        let paragraphStyleFactory = self.paragraphStyleFactory
        switch textStyle {
        case .paragraph:
            return { attributes in
                paragraphStyleFactory.paragraphStyle(of: .centerAlignedWideSpacing)
                    .applied(on: textStyleFactory.textStyle(of: .subheadline)
                        .applied(on: attributes))
            }
        case .warning:
            return  { attributes in
               textStyleFactory.textStyle(of: .warning)
                   .applied(on: attributes)
           }
        case .emphasized(let textStyle):
            return { attributes in
                textStyleFactory.textStyle(of: textStyle)
                    .applied(on: attributes)
            }
        }
    }
}
