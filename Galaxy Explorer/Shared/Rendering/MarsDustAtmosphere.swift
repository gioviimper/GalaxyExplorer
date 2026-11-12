import SceneKit

// Preserve the bundled texture color while using its brightness for dust transparency.
// This lightweight haze is illustrative and does not represent live weather.
@MainActor
enum MarsDustAtmosphere {
    static let densityShader = """
        #pragma body

        float dustU = _surface.diffuseTexcoord.x;
        float dustV = _surface.diffuseTexcoord.y;
        float dustDensity = (
            _surface.diffuse.r + _surface.diffuse.g + _surface.diffuse.b
        ) / 3.0;
        float dustPolarFade =
            smoothstep(0.02, 0.22, dustV) *
            (1.0 - smoothstep(0.78, 0.98, dustV));

        // Break up broad cloud shapes into thinner, uneven suspended veils.
        float dustWisps = 0.72 + 0.18 * sin(
            dustU * 125.663706 + sin(dustV * 50.265482) * 2.0
        );
        float dustMask = smoothstep(0.08, 0.90, dustDensity);
        _surface.diffuse.a *= dustMask * dustPolarFade * dustWisps;
        """

    static let driftShader = """
        #pragma body

        float dustLatitude = _geometry.texcoords[0].y;
        float dustFlow = smoothstep(0.02, 0.20, dustLatitude)
            * (1.0 - smoothstep(0.80, 0.98, dustLatitude));
        // Small bounded offsets suggest gusts without stretching the map over time.
        _geometry.texcoords[0].x +=
            0.003 * sin(u_time * 0.7 + dustLatitude * 25.132741) * dustFlow;
        _geometry.texcoords[0].y +=
            0.0015 * sin(u_time * 0.45 + dustLatitude * 12.566371) * dustFlow;
        """

    static func configure(_ material: SCNMaterial) {
        material.name = "marsDustMaterial"
        material.shaderModifiers = [.surface: densityShader]
    }

    static func setMotionEnabled(_ enabled: Bool, material: SCNMaterial) {
        guard material.name == "marsDustMaterial" else { return }
        if enabled {
            material.shaderModifiers = [.surface: densityShader, .geometry: driftShader]
        } else {
            // Keep the static dust mask while removing automatic shader movement.
            material.shaderModifiers = [.surface: densityShader]
        }
    }
}
