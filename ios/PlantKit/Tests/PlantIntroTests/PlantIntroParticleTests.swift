import XCTest
@testable import PlantIntro

@MainActor
final class PlantIntroParticleTests: PlantIntroXCTestCase {
    func test_make_deliversBetweenTwelveAndEighteenParticles() {
        XCTAssertTrue((12...18).contains(PlantIntroParticle.make().count))
    }

    func test_make_isDeterministic() {
        XCTAssertEqual(PlantIntroParticle.make(), PlantIntroParticle.make())
    }

    func test_make_keepsEveryParticleInsideTheScreenAndTheTimeline() {
        PlantIntroParticle.make().forEach { particle in
            XCTAssertTrue((0...1).contains(particle.x))
            XCTAssertTrue((0...1).contains(particle.startY))
            XCTAssertGreaterThanOrEqual(particle.delay, PlantIntroTimeline.glowStart)
            XCTAssertLessThanOrEqual(particle.delay + particle.life, PlantIntroTimeline.handoffStart + 0.0001)
            XCTAssertTrue((1...6).contains(particle.size))
        }
    }

    func test_make_spreadsParticlesAcrossTheWidth() {
        let xs = PlantIntroParticle.make().map(\.x)

        XCTAssertGreaterThan(xs.max()! - xs.min()!, 0.5)
    }

    func test_state_isHiddenBeforeItsDelayAndAfterItsLife() {
        let sut = PlantIntroParticle(x: 0.5, startY: 0.8, rise: 0.3, drift: 0.02, delay: 0.4, life: 0.5, size: 3)

        XCTAssertNil(sut.state(at: 0.39))
        XCTAssertNil(sut.state(at: 0.91))
    }

    func test_state_risesAndFadesInAndOut() {
        let sut = PlantIntroParticle(x: 0.5, startY: 0.8, rise: 0.3, drift: 0, delay: 0.4, life: 0.5, size: 3)

        let early = sut.state(at: 0.45)!
        let middle = sut.state(at: 0.65)!
        let late = sut.state(at: 0.89)!

        XCTAssertGreaterThan(middle.opacity, early.opacity)
        XCTAssertGreaterThan(middle.opacity, late.opacity)
        XCTAssertLessThan(middle.y, early.y)
        XCTAssertLessThan(late.y, middle.y)
        XCTAssertEqual(middle.y, 0.65, accuracy: 0.0001)
    }
}
