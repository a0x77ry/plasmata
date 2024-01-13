class_name Population

var genomes
var species

var selection_rate
var target_population

var random = RandomNumberGenerator.new()


func _init(_genomes=[], _species=[], _selection_rate=0.3, _target_population=52):
  genomes = _genomes
  species = _species
  selection_rate = _selection_rate
  target_population = _target_population

  random.randomize()


func calculate_all_species_adj_fitness():
  var all_species_adj_fitness = 0.0
  for sp in species:
    all_species_adj_fitness += sp.total_adjusted_fitness
  return all_species_adj_fitness

func kill_empty_species():
  var species_to_erase = []
  for sp in species:
    if sp.parent_genomes.size() == 0 || sp.members.size() == 0:
      species_to_erase.append(sp)

func fill_parent_genomes():
  var total_parents := 0
  for sp in species:
    total_parents += sp.parent_genomes.size()
  while total_parents * (1.0 / selection_rate) < target_population:
    for sp in species:
      if sp.parent_genomes.size() > 0 && random.randf() < 1.0 / species.size():
        sp.parent_genomes.append(sp.members[-1])
        total_parents += 1


func initialize_genomes_with_fitness(agents: Array):
  var _genomes = []
  for agent in agents:
    agent.get_fitness()
    _genomes.append(agent.genome.duplicate())
  genomes = _genomes


func speciate():
  if !species.empty():
    for sp in species:
      sp.reset_species()
