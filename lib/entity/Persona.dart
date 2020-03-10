
class Persona {
  final String key;
  final String thumbnail;
  final List<Reaction> neutralReactions;
  final List<Reaction> happyReactions;
  final List<Reaction> sadReactions;
  final List<Reaction> angryReactions;

  const Persona(this.key, this.thumbnail, {
    this.neutralReactions = const [],
    this.happyReactions = const [],
    this.sadReactions = const [],
    this.angryReactions = const [],
  });
}

class Reaction {
  final String imgPath;
  final String audioPath;

  const Reaction(this.imgPath, this.audioPath);
}