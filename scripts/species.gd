class_name Species

const STALE_GENS_BEFORE_DEATH = 15
const REQUIRED_SPECIES_IMPROVEMENT = 50
const SELECTION_RATE = 0.3
const CROSSOVER_RATE = 0.75
const DISABLED_LINK_SELECTION_RATE = 0.75

const Genome = preload("res://scripts/genome.gd")

var prototype
var members
var parent_genomes
var avg_fitness
var total_adjusted_fitness
var random = RandomNumberGenerator.new()


func _init(_prototype, _members=[], _parent_genomes=[], _avg_fitness=[],
    _total_adjusted_fitness=0):
  prototype = _prototype
  members = _members
  parent_genomes = _parent_genomes
  avg_fitness = _avg_fitness
  total_adjusted_fitness = _total_adjusted_fitness
  
  random.randomize()


func share_fitness():
  for member_genome in members:
    member_genome.adjusted_fitness = member_genome.fitness / members.size()


func calculate_avg_fitness():
  if members.size() == 0:
    avg_fitness = []
    total_adjusted_fitness = 0.0
    return

  var total_fitness = 0.0
  for member_genome in members:
    total_fitness += member_genome.fitness
    total_adjusted_fitness += member_genome.adjusted_fitness
  if avg_fitness.size() < STALE_GENS_BEFORE_DEATH:
    avg_fitness.append(total_fitness / float(members.size()))
  else:
    avg_fitness.remove(0)
    avg_fitness.push_back(total_fitness / float(members.size())) # same as append

func empty_stale_spieces():
  if avg_fitness.size() > STALE_GENS_BEFORE_DEATH:
    if avg_fitness[-1] - avg_fitness[0] < REQUIRED_SPECIES_IMPROVEMENT:
      members = [] # if there is no improvement after some generations kill the species

func select_in_species(number_of_expected_parents):
  # calculate the avg_fitness
  calculate_avg_fitness()
  empty_stale_spieces()

  # calculate the number of parents for each species
  members.sort_custom(GenomeSorter, "sort_ascenting")
  var parents_number = round((total_adjusted_fitness / Main.population.all_species_adj_fitness) \
      * number_of_expected_parents)
  if members.size() == 0:
    parents_number = 0
  # Add the last (best performing) genomes of the species or random
  if parents_number > 0:
    for i in range(1, parents_number):
      if members.size() >= i:
        # Append normal member
        parent_genomes.append(members[-i])
      else:
        # Append random member
        parent_genomes.append(members[random.randi_range(0, members.size() - 1)])


func couple_crossover(couple_genomes: Array, offspring_number: int) -> Array:
  var crossovered_genomes := []
  var fittest_parent
  var weakest_parent
  if couple_genomes[0].fitness > couple_genomes[1].fitness:
    fittest_parent = couple_genomes[0]
    weakest_parent = couple_genomes[1]
  else:
    fittest_parent = couple_genomes[1]
    weakest_parent = couple_genomes[0]

  for _i in offspring_number:
    var crossed_genome := Genome.new()

    # inherit nodes from the fittest parent
    crossed_genome.input_nodes = fittest_parent.input_nodes
    crossed_genome.hidden_nodes = fittest_parent.hidden_nodes
    crossed_genome.output_nodes = fittest_parent.output_nodes
    crossed_genome.links = []

    var weakest_parent_ids = []
    for link in weakest_parent.links:
      weakest_parent_ids.append(link.id)
    for link in fittest_parent.links:
      if link.id in weakest_parent_ids: # matching links, random selection
        var weak_link
        for wl in weakest_parent.links:
          if wl.id == link.id:
            weak_link = wl
            break
        # If one of the two matching links is disabled, disable the offspring one in a certain rate
        if !link.is_enabled:
          if random.randf() < DISABLED_LINK_SELECTION_RATE:
            crossed_genome.links.append(link)
          else:
            crossed_genome.links.append(weak_link)
        elif !weak_link.is_enabled:
          if random.randf() < 1 - DISABLED_LINK_SELECTION_RATE:
            crossed_genome.links.append(link)
          else:
            crossed_genome.links.append(weak_link)
        # Or else random choice between the two parent links
        elif random.randf() > 0.5:
          crossed_genome.links.append(link)
        else:
          crossed_genome.links.append(weak_link)
      else: # excess or disjoint links, from the fittest
        crossed_genome.links.append(link)
    crossovered_genomes.append(crossed_genome)
  return crossovered_genomes

func crossover():
  var crossovered_genomes = []
  if parent_genomes.size() == 0:
    return []
  elif parent_genomes.size() % 2 != 0:
    parent_genomes.append(parent_genomes[0]) # add a genome to become even
  # Crossover couples of parent_genomes in crossovered_genomes
  for i in range(0, parent_genomes.size()-1, 2):
    var couple_genomes
    if i == 0:
      couple_genomes = [parent_genomes[i], parent_genomes[i]]
    else:
      couple_genomes = [parent_genomes[i-2], parent_genomes[i-1]]
    var number_of_offspring_each_couple = int(round((1.0 / SELECTION_RATE) * 2.0))
    var couple_crossovered_genomes = [] 
    if random.randf() < CROSSOVER_RATE:
      couple_crossovered_genomes = couple_crossover(couple_genomes,
          number_of_offspring_each_couple)
    else:
      for c in number_of_offspring_each_couple - 1:
        couple_crossovered_genomes.append(couple_genomes[c % 2])
    crossovered_genomes.append_array(couple_crossovered_genomes)
  return crossovered_genomes


# Reset everything except the prototype
func reset_species():
  members = []
  parent_genomes = []
  avg_fitness = []
  total_adjusted_fitness = 0.0


class GenomeSorter:
  static func sort_ascenting(a, b):
    if a.fitness < b.fitness:
      return true
    return false
