class Segment {
  final int start;

  final bool moving;

  final bool flagged;

  final bool paused;

  Segment(
    this.start,
    this.moving, {
    this.flagged = false,
    this.paused = false,
  });
}