String computeYearLabel({required String degree, required int semesterNumber}) {
  if (degree == 'Other') {
    return '1';
  }

  if (degree == 'BM' || degree == 'BA') {
    final year = ((semesterNumber - 1) ~/ 2) + 1;

    switch (year) {
      case 1:
        return 'Freshman';

      case 2:
        return 'Sophomore';

      case 3:
        return 'Junior';

      case 4:
        return 'Senior';

      default:
        return 'Senior+${year - 4}';
    }
  }

  if (degree == 'MA') {
    if (semesterNumber <= 2) {
      return 'MA';
    }

    return 'MA+${semesterNumber - 1}';
  }

  if (degree == 'DMA') {
    if (semesterNumber <= 2) {
      return 'DMA';
    }

    return 'DMA+${semesterNumber - 1}';
  }

  return 'Unknown';
}

int computeDefaultMinimum({
  required String degree,

  required int semesterNumber,
}) {
  if (degree == 'Other') {
    return 4;
  }

  if (degree == 'MA' || degree == 'DMA') {
    return 12;
  }

  if (semesterNumber <= 1) {
    return 5;
  }

  if (semesterNumber == 2) {
    return 6;
  }

  if (semesterNumber == 3) {
    return 7;
  }

  if (semesterNumber == 4) {
    return 8;
  }

  if (semesterNumber == 5) {
    return 9;
  }

  if (semesterNumber == 6) {
    return 10;
  }

  if (semesterNumber == 7) {
    return 11;
  }

  return 12;
}

int computeSemesterNumber({required String startTerm, required int startYear}) {
  final now = DateTime.now();

  final currentTerm = now.month >= 8 ? 'Fall' : 'Spring';

  int currentIndex = now.year * 2;

  if (currentTerm == 'Spring') {
    currentIndex -= 1;
  }

  int startIndex = startYear * 2;

  if (startTerm == 'Spring') {
    startIndex -= 1;
  }

  return (currentIndex - startIndex) + 1;
}
