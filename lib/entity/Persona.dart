
class Persona {
  final String key;
  final String thumbnail;
  final List<Reaction> happyReactions;

  const Persona(this.key, this.thumbnail, {
    this.happyReactions = const [],
  });
}

class Reaction {
  final String imgPath;
  final String audioPath;

  const Reaction(this.imgPath, this.audioPath);
}