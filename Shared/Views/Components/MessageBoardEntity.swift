//
//  MessageBoardEntity.swift
//  TanyaLe
//
//  Created by Alisha Listya Wardhani on 06/07/26.
//

import SwiftUI
import RealityKit
import UIKit

// MARK: - Message board

/// A non-interactive floating AR card that shows a message a user left at this
/// exact spot. Built the same way as the survey cards (SwiftUI views rendered
/// to textures on planes, via the shared `SurveyCard` helpers) so it matches
/// their look — but it has no options or submit, it just displays the
/// "Message" title and the message body.
@MainActor
final class MessageBoardController: ARSurveyBoard {

    let rootEntity = Entity()

    private let message: String

    private init(message: String) {
        self.message = message
    }

    /// Creates the message card. Async because texture uploads to the GPU are async.
    static func make(message: String) async -> MessageBoardController? {
        let controller = MessageBoardController(message: message)
        guard await controller.buildCard() else { return nil }
        return controller
    }

    // The board is display-only, so taps never belong to it.
    func handleTap(on entity: Entity, at worldPosition: SIMD3<Float>?, cameraPosition: SIMD3<Float>) -> Bool {
        false
    }

    private func buildCard() async -> Bool {
        let s = SurveyCard.metersPerPoint

        guard let title = await SurveyCard.renderPiece(MessageTitleView()),
              let body = await SurveyCard.renderPiece(MessageBodyView(text: message)) else { return false }

        // Total card height in points: padding, title, spacing, body, padding.
        var contentHeight = title.sizePoints.height + SurveyCard.sectionSpacingPoints
        contentHeight += body.sizePoints.height
        let cardHeight = contentHeight + SurveyCard.paddingPoints * 2

        rootEntity.addChild(SurveyCard.backgroundEntity(cardHeightPoints: cardHeight))

        // Stack the pieces downward from the top of the card, slightly in front
        // of the background so they render on top.
        var cursor = Float(cardHeight) * s / 2 - Float(SurveyCard.paddingPoints) * s

        let titleEntity = SurveyCard.pieceEntity(title)
        titleEntity.position = [0, cursor - Float(title.sizePoints.height) * s / 2, 0.002]
        rootEntity.addChild(titleEntity)
        cursor -= Float(title.sizePoints.height + SurveyCard.sectionSpacingPoints) * s

        let bodyEntity = SurveyCard.pieceEntity(body)
        bodyEntity.position = [0, cursor - Float(body.sizePoints.height) * s / 2, 0.002]
        rootEntity.addChild(bodyEntity)

        return true
    }
}

// MARK: - Card piece designs (rendered to textures)

private struct MessageTitleView: View {
    var body: some View {
        Text("Message")
            .font(.system(size: 30, weight: .heavy))
            .foregroundStyle(.black)
            .frame(width: 292, alignment: .leading)
            .background(Color.white)
    }
}

private struct MessageBodyView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 20))
            .foregroundStyle(.black)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 292, alignment: .leading)
            .background(Color.white)
    }
}
