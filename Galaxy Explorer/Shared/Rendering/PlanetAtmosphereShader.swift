// MARK: - Atmospheric shader

enum PlanetAtmosphereShader {
    // Local, bounded swirls suggest atmospheric motion without spinning the body.
    // This is an illustrative texture effect, not a weather simulation.
    private static func circularVortices(speed: String, strength: String) -> String {
        return """
            #pragma body

            float cloudU = _geometry.texcoords[0].x;
            float cloudV = _geometry.texcoords[0].y;
            float cloudOffsetU = 0.0;
            float cloudOffsetV = 0.0;

            for (int cloudIndex = 0; cloudIndex < 4; cloudIndex++) {
                float cloudBand = float(cloudIndex);
                float cloudCenterU = 0.12 + cloudBand * 0.25;
                float cloudCenterV = 0.5 + 0.16 * sin(cloudBand * 2.1);
                float cloudDeltaU = cloudU - cloudCenterU;
                float cloudDeltaV = cloudV - cloudCenterV;

                // Wrap longitude and compensate for the map aspect ratio.
                cloudDeltaU -= floor(cloudDeltaU + 0.5);
                cloudDeltaU *= 2.0;

                float cloudRadius = sqrt(
                    cloudDeltaU * cloudDeltaU + cloudDeltaV * cloudDeltaV
                );
                float cloudInfluence = 1.0 - smoothstep(0.02, 0.24, cloudRadius);
                float cloudDirection = (cloudIndex % 2 == 0) ? 1.0 : -1.0;
                // A uniform phase produces closed circular paths without cumulative shear.
                float cloudAngle = cloudDirection * u_time * \(speed);
                float cloudWeight = cloudInfluence * \(strength);
                float cloudSine = sin(cloudAngle);
                float cloudCosine = cos(cloudAngle);

                // Rotate local texture details without rotating the planet node.
                cloudOffsetU += (
                    cloudCosine * cloudDeltaU - cloudSine * cloudDeltaV - cloudDeltaU
                ) * 0.5 * cloudWeight;
                cloudOffsetV += (
                    cloudSine * cloudDeltaU + cloudCosine * cloudDeltaV - cloudDeltaV
                ) * cloudWeight;
            }

            _geometry.texcoords[0].x = cloudU + cloudOffsetU;
            _geometry.texcoords[0].y = cloudV + cloudOffsetV;
            """

    }

    static func make(for style: PlanetAtmosphereStyle) -> String {
        let amplitude: String
        let speed: String

        switch style {
        case .jupiterBands:
            amplitude = "0.012"
            speed = "0.8"

        case .saturnBands:
            // Use Jupiter's alternating flow with a smaller, slower displacement.
            amplitude = "0.004"
            speed = "0.5"

        case .uranusVortices:
            // Keep local motion bounded and softer than Neptune's visible storms.
            return circularVortices(speed: "0.70", strength: "0.25")

        case .neptuneVortices:
            return circularVortices(speed: "0.55", strength: "0.35")

        case .solarPlasma:
            return SunAtmosphere.surfaceShader

        case .none:
            amplitude = "0.0"
            speed = "0.0"
        }

        return """
            #pragma body

            float latitude = _geometry.texcoords[0].y;

            // Move neighboring atmospheric bands in opposite directions.
            float bandDirection = sin(latitude * 50.265482);

            // Bound displacement to prevent cumulative texture stretching.
            float displacement =
                sin(u_time * \(speed)) * \(amplitude);

            // Reduce distortion near the poles.
            float polarFade =
                smoothstep(0.02, 0.15, latitude) *
                (1.0 - smoothstep(0.85, 0.98, latitude));

            _geometry.texcoords[0].x +=
                bandDirection * displacement * polarFade;
            """
    }
}
