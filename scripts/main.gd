extends Node2D

const NUMBER_OF_SELECTED := 10
const MUTATION_RATE = 0.1
const MUTATION_STANDARD_DEVIATION = 2.0
const EXPECTED_MUTATED_GENES = 1.0
const DEVIATION_FROM_PARENTS = 0.1
const SELECTION_EXPONENT = 2.0
const C1 := 1.0
const C2 := 1.0
const C3 := 0.4
const dt := 0.3


var random = RandomNumberGenerator.new()
var used_node_ids := []
var genomes := [] # A list of genomes
var species := [] 
var generation := 0
# var init_rot = rand_range(-PI, PI)


func _ready():
  random.randomize()


func calculate_fitness(curve: Curve2D, agents: Array) -> Array:
  var _genomes = []
  for agent in agents:
    agent.genome["fitness"] = curve.get_closest_offset(agent.position)
    _genomes.append(agent.genome)
  return _genomes


func select_naive(agents):
  agents.sort_custom(AgentSorter, "sort_ascenting")
  var fittest_agents = agents.slice(-NUMBER_OF_SELECTED, -1)
  # print("fittest_agents length is %s" % fittest_agents.size())
  var _genomes = []
  for agent in fittest_agents:
    # print("agent's position.x is: %s" % agent.position.x)
    _genomes.append(agent.genome.duplicate())
    return _genomes


func select_in_species(number_of_expected_parents):
  random.randomize()
  # calculate the avg_fitness for each species
  var total_species_fitness = 0.0
  for sp in species:
    var total_fitness = 0.0
    for member_genome in sp["members"]:
      total_fitness += member_genome["fitness"]
    sp["avg_fitness"] = total_fitness / float(sp["members"].size())
    total_species_fitness += sp["avg_fitness"]

  # calculate the number of offspring for each species
  for sp in species:
    sp.sort_custom(GenomeSorter, "sort_ascenting")
    var parents_number = round((sp["avg_fitness"] / total_species_fitness) 
        * number_of_expected_parents)
    # add the last (best performing) genomes of the species
    for i in range(1, parents_number):
      sp["parent_genomes"].append(sp["members"][-i])


func select_roulette(curve, agents):
  random.randomize()
  var total_distance := 0.0
  var _genomes = []

  var offset = 0.0
  for agent in agents:
  #   total_distance += pow(agent.global_position.x, 2.0)
    total_distance += pow(curve.get_closest_offset(agent.position), SELECTION_EXPONENT)
  while _genomes.size() < ceil(agents.size() / 2.0):
    for agent in agents:
      offset = curve.get_closest_offset(agent.position)
      # var selection_probability = pow(agent.global_position.x, 2.0) / total_distance
      var selection_probability = pow(offset, SELECTION_EXPONENT) / total_distance
      if random.randf() < selection_probability:
        agent.genome["fitness"] = offset
        _genomes.append(agent.genome.duplicate())
  return _genomes


func crossover_sbx(parent_genomes_original, target_polutation: int):
  random.randomize()
  var parent_genomes = parent_genomes_original.duplicate()
  var original_genomes_size = parent_genomes.size()
  var offspring_genomes := []
  # while parent_genomes.size() >= 2:
  #   var couple := [parent_genomes.pop_at(random.randi_range(0, parent_genomes.size() - 1)),
  #       parent_genomes.pop_at(random.randi_range(0, parent_genomes.size() - 1))]
  #
  #   offspring_genomes.append_array(couple_crossover_sbx(couple, (target_polutation / original_genomes_size) * 2))
  #   print("Number of offspring: %s" % ((target_polutation / original_genomes_size) * 2))
  for _i in range(parent_genomes.size() / 2):
    var couple := [parent_genomes[random.randi_range(0, parent_genomes.size() - 1)],
        parent_genomes[random.randi_range(0, parent_genomes.size() - 1)]]

    offspring_genomes.append_array(couple_crossover_sbx(couple, (target_polutation / original_genomes_size) * 2))
  #   print("Number of offspring: %s" % ((target_polutation / original_genomes_size) * 2))
  # print("Offspring genomes size after crossover: %s" % offspring_genomes.size())
  return offspring_genomes


func couple_crossover_sbx(couple_genomes, number_of_offspring):
  random.randomize()
  var crossovered_genomes := []
  var crossovered_genome = couple_genomes[0].duplicate()
  for _i in range(number_of_offspring):
    for i in range(crossovered_genome["links"].size()):
      var b = random.randfn(1.0, DEVIATION_FROM_PARENTS)
      var offspring_link_weight_1: float
      var offspring_link_weight_2: float
      var offspring_link_bias_1: float
      var offspring_link_bias_2: float

      var p0_w = couple_genomes[0]["links"][i]["weight"]
      var p1_w = couple_genomes[1]["links"][i]["weight"]
      var p0_b = couple_genomes[0]["links"][i]["bias"]
      var p1_b = couple_genomes[1]["links"][i]["bias"]
      offspring_link_weight_1 = ((1.0 + b) * p0_w + (1.0 - b) * p1_w) / 2.0
      offspring_link_weight_2 = ((1.0 - b) * p0_w + (1.0 + b) * p1_w) / 2.0
      offspring_link_bias_1 = ((1.0 + b) * p0_b + (1.0 - b) * p1_b) / 2.0
      offspring_link_bias_2 = ((1.0 - b) * p0_b + (1.0 + b) * p1_b) / 2.0

      crossovered_genome["links"][i]["weight"] = offspring_link_weight_1
      crossovered_genome["links"][i]["weight"] = offspring_link_weight_2
      crossovered_genome["links"][i]["bias"] = offspring_link_bias_1
      crossovered_genome["links"][i]["bias"] = offspring_link_bias_2
    crossovered_genomes.append(crossovered_genome)
  # print("Couple crossover returning %s offspring" % crossovered_genomes.size())
  return crossovered_genomes


func mutate(parent_genomes):
  random.randomize()
  var check := false
  var mutated_genomes = parent_genomes.duplicate(true)
  for genome in mutated_genomes:
    if random.randf() < MUTATION_RATE:
      check = false
      for link in genome["links"]:
        if random.randf() < EXPECTED_MUTATED_GENES / float(genome["links"].size()):
          # print("Weight Mutated")
          # print("Original: %s" % link["weight"])
          link["weight"] = random.randfn(link["weight"], MUTATION_STANDARD_DEVIATION)
          # link["weight"] = -link["weight"]
          # print("Mutated: %s" % link["weight"])
        if random.randf() < EXPECTED_MUTATED_GENES / float(genome["links"].size()):
          link["bias"] = random.randfn(link["bias"], MUTATION_STANDARD_DEVIATION)


  if check:
    for i in parent_genomes.size():
      for link_i in parent_genomes[i]["links"].size():
        var original_w = parent_genomes[i]["links"][link_i]["weight"]
        var mutated_w = mutated_genomes[i]["links"][link_i]["weight"]
        if original_w != mutated_w:
          print("Genome %s. Original: %s. Mutated: %s" % [i, original_w, mutated_w])

  return mutated_genomes


func speciate():
  species = []
  for genome in genomes:
    var gen_all_nodes = genome["input_nodes"] + genome["hidden_nodes_1"] \
        + genome["output_nodes"] + genome["links"];
    var gen_all_ids = []
    for node in gen_all_nodes:
      gen_all_ids.append(node["id"])
    var gen_max_id = gen_all_ids.max()

    var is_different_species := true
    for sp in species:
      var N = max(genome.size(), sp["prototype"].size()) # find N

      var prot = sp["prototype"]
      var prot_all_nodes = prot["input_nodes"] + prot["hidden_nodes_1"] \
          + prot["output_nodes"] + prot["links"]
      var prot_all_ids = []
      for node in prot_all_nodes:
        prot_all_ids.append(node["id"])
      var prot_max_id = prot_all_ids.max()
      var excess_genes_num = abs(gen_max_id - prot_max_id) # find excess genes

      var min_id = min(gen_max_id, prot_max_id)
      var disjoined_genes_num = 0
      var weight_diffs = []
      for gen_n in gen_all_nodes:
        if !prot_all_ids.has(gen_n["id"]) and gen_n["id"] <= min_id:
          disjoined_genes_num += 1 #find disjoined genes

        for prot_n in prot_all_nodes:
          if prot_n.has("weight") && prot_n["id"] == gen_n["id"]:
            assert(gen_n.has("weight"), "Error in change_generation(). pron_n is a link while gen_n isn't")
            weight_diffs.append(abs(prot_n["weight"] - gen_n["weight"]))
      var weight_diffs_sum = 0.0
      for weight_diff in weight_diffs:
        weight_diffs_sum += weight_diff
      var avg_weight_diff = weight_diffs_sum / weight_diffs.size() # find average weight differences

      var compatibility_distance = ((C1 * excess_genes_num) / N) \
          + ((C2 * disjoined_genes_num) / N) \
          + (C3 * avg_weight_diff)
      print("Compatibility distance: %s" % compatibility_distance)
      if compatibility_distance < dt:
        is_different_species = false
        sp["members"].append(genome)
        break # we don't want a genome to belong to 2 different species
    if is_different_species || species.empty():
      add_species(genome)


func add_species(genome):
  var sp = {"prototype": genome, "members": [genome], "avg_fitness": [],
      "parent_genomes": []}
  species.append(sp)


func generate_UID():
  # var id = randi() % 1000
  # while id in used_node_ids:
  #   id = randi() % 1000
  return used_node_ids.max() + 1 



class AgentSorter:
  static func sort_ascenting(a, b):
    if a.position.x < b.position.x:
      return true
    return false

class GenomeSorter:
  static func sort_ascenting(a, b):
    if a["fitness"] < b["fitness"]:
      return true
    return false
