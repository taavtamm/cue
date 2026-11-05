import Foundation

extension ExportLayout {
    /// A box PowerPoint draws as a shape: its fill, outline, corners, shadow.
    public struct Shape: Sendable, Equatable, Decodable {
        /// The box before its rotation, in canvas pixels.
        public let box: Box
        /// Degrees, clockwise.
        public let rotation: Double
        /// rect, roundRect, ellipse or line (a thin box drawn as a line through its middle).
        public let geometry: String
        /// Corner radius in canvas pixels.
        public let radius: Double
        /// The product of its and its ancestors' opacity.
        public let opacity: Double
        public let fill: Fill?
        /// A border that's the same on every side.
        public let line: Line?
        /// Top, right, bottom, left borders when they differ (nil where there is none).
        public let sides: [Line?]?
        public let shadow: Shadow?
        public let order: Int
    }

    /// A solid colour or a linear gradient.
    public struct Fill: Sendable, Equatable, Decodable {
        public struct Stop: Sendable, Equatable, Decodable {
            public let color: String
            /// 0…1 along the gradient line.
            public let position: Double
        }

        /// solid or linear.
        public let type: String
        public let color: String?
        /// CSS degrees: 0 points up, 90 right.
        public let angle: Double?
        public let stops: [Stop]?
    }

    public struct Line: Sendable, Equatable, Decodable {
        public let width: Double
        public let color: String
        /// solid, dash or dot.
        public let dash: String

        public init(width: Double, color: String, dash: String) {
            self.width = width
            self.color = color
            self.dash = dash
        }
    }

    /// An outer box shadow.
    public struct Shadow: Sendable, Equatable, Decodable {
        public let color: String
        public let x, y, blur: Double
    }
}
