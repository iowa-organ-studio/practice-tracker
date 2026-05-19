class Segment {
  final int start;

  final bool moving;

  final bool flagged;

  final bool paused;

  final bool resolved;

  final bool fraudulent;

  Segment(
    this.start,
    this.moving, {
    this.flagged = false,
    this.paused = false,
    this.resolved = false,
    this.fraudulent = false,
  });
}