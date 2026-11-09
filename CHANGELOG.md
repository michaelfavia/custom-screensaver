# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-11-09
### Added
- Corner plasma: a hit within 10 px of a corner is nudged into the exact corner so the logo bounces
  straight back out, then the screen flashes, rainbow ripples spread from the logo and follow it, and a
  tapered rainbow plasma tail trails it until the next wall
### Changed
- Logo is a transparent cut-out tinted by a small shader, so only the letters, disc and TM are colored
- Animation is driven by a 30 fps timer instead of PropertyAnimations, so corner hits can be detected

## [1.0.1] - 2022-01-07
### Changed
- Replaced logo with an inverted one

## [1.0.0] - 2022-01-05
Initial release

[Unreleased]: https://github.com/webosbrew/custom-screensaver/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/webosbrew/custom-screensaver/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/webosbrew/custom-screensaver/releases/tag/v1.0.0
