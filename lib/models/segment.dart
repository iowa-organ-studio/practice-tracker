class Segment {
  final int start;
  final bool moving;
  final bool flagged;

  Segment(
    this.start,
    this.moving, {
    this.flagged = false,
  });
}