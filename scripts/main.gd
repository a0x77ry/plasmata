extends Node2D

const NUMBER_OF_SELECTED := 10
const MUTATION_RATE = 0.3
const MUTATION_STANDARD_DEVIATION = 2.0
const ORIGINAL_WEIGHT_VALUE_LIMIT = 2.0
const ORIGINAL_BIAS_VALUE_LIMIT = 2.0
const EXPECTED_MUTATED_GENES = 1.0
const EXPECTED_MUTATED_GENE_RATE = 0.1
const DEVIATION_FROM_PARENTS = 0.1
const SELECTION_EXPONENT = 2.0
const C1 := 1.0
const C2 := 1.0
const C3 := 0.4
const dt := 0.3
const SELECTION_RATE = 0.5
const TARGET_POPULATION = 52
const STALE_GENS_BEFORE_DEATH = 20
const REQUIRED_SPECIES_IMPROVEMENT = 50


var random = RandomNumberGenerator.new()
# var used_node_ids := []
var max_id_used := 0
var genomes := [] # A list of genomes
var species := [] 
var generation := 0
var level
var init_rot = rand_range(-PI, PI)


func _ready():
  random.randomize()
  get_level()


func get_level():
  level = get_tree().get_nodes_in_group("level")[0]


func calculate_fitness(curve: Curve2D, agents: Array):
  var _genomes = []
  for agent in agents:
    agent.genome["fitness"] = curve.get_closest_offset(agent.position)
    _genomes.append(agent.genome.duplicate())
  genomes = _genomes


func share_fitness():
  for sp in species:
    for member_genome in sp["members"]:
      member_genome["adjusted_fitness"] = member_genome["fitness"] / sp.size()


func select_in_species(number_of_expected_parents):
  # calculate the avg_fitness for each species
  var all_species_adj_fitness = 0.0
  for sp in species:
    if sp["members"].size() == 0:
      sp["avg_fitness"] = []
      sp["total_adjusted_fitness"] = 0
      continue

    var total_adjusted_fitness = 0.0
    var total_fitness = 0.0
    for member_genome in sp["members"]:
      total_fitness += member_genome["fitness"]
      total_adjusted_fitness += member_genome["adjusted_fitness"]
    if sp["avg_fitness"].size() < STALE_GENS_BEFORE_DEATH:
      sp["avg_fitness"].append(total_fitness / float(sp["members"].size()))
    else:
      sp["avg_fitness"].remove(0)
      sp["avg_fitness"].push_back(total_fitness / float(sp["members"].size())) # same as append
      if sp["avg_fitness"][-1] - sp["avg_fitness"][0] < REQUIRED_SPECIES_IMPROVEMENT:
        sp["members"] = [] # if there is no improvement after some generations kill the species
    sp["total_adjusted_fitness"] = total_adjusted_fitness
    all_species_adj_fitness += total_adjusted_fitness
    

  # calculate the number of parents for each species
  # var c := 0
  var total_parents := 0
  var species_to_remove = []
  for sp in species:
    sp["members"].sort_custom(GenomeSorter, "sort_ascenting")
    var parents_number = round((sp["total_adjusted_fitness"] / all_species_adj_fitness) \
        * number_of_expected_parents)
    if sp["members"].size() == 0:
      # sp["parent_genomes"] = []
      parents_number = 0
    # add the last (best performing) genomes of the species
    if parents_number > 0:
      for i in range(1, parents_number):
        if sp["members"].size() >= i:
          # print("Append normal member")
          sp["parent_genomes"].append(sp["members"][-i])
          total_parents += 1
        else:
          # print("Append random member")
          sp["parent_genomes"].append(sp["members"][random.randi_range(0, sp["members"].size() - 1)])
          total_parents += 1
    else:
      species_to_remove.append(sp)
  for sp_to_remove in species_to_remove:
    if species.size() > 0:
      species.erase(sp_to_remove) # remove any species with zero members or parent members
  var species_with_parent_genomes_left := false
  for sp in species:
    if sp["parent_genomes"].size() > 0:
      species_with_parent_genomes_left = true
      break
  if !species_with_parent_genomes_left:
    return
  while total_parents * (1.0 / SELECTION_RATE) < TARGET_POPULATION:
    for sp in species:
      if sp["parent_genomes"].size() > 0 && random.randf() < 1.0 / species.size():
        sp["parent_genomes"].append(sp["members"][-1])
        total_parents += 1


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


func crossover_sbx(parent_genomes_original, target_poputation: int):
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

    offspring_genomes.append_array(couple_crossover_sbx(couple, (target_poputation / original_genomes_size) * 2))
  #   print("Number of offspring: %s" % ((target_polutation / original_genomes_size) * 2))
  # print("Offspring genomes size after crossover: %s" % offspring_genomes.size())
  return offspring_genomes


func crossover():
  var do_parents_exist := false
  for sp in species:
    if sp["parent_genomes"].size() > 0:
      do_parents_exist = true
      break
  if !do_parents_exist:
    return []
  # random.randomize()
  var crossovered_genomes := []
  for sp in species:
    if sp["parent_genomes"].size() == 0:
      continue
    elif sp["parent_genomes"].size() % 2 != 0:
      sp["parent_genomes"].append(sp["parent_genomes"][0]) # add a genome to become even
    # if sp["parent_genomes"].size() == 1:
    #   sp["parent_genomes"].append(sp["parent_genomes"][0]) # add a genome to become even
    # for i in range(0, floor((sp["parent_genomes"].size() - 1) * SELECTION_RATE), 2):
    for i in range(0, sp["parent_genomes"].size()-1, 2):
      var couple_genomes
      if i == 0:
        couple_genomes = [sp["parent_genomes"][i], sp["parent_genomes"][i]]
      else:
        couple_genomes = [sp["parent_genomes"][i-2], sp["parent_genomes"][i-1]]
      # if sp["parent_genomes"].size()-1 > i:
      #   couple_genomes = [sp["parent_genomes"][i], sp["parent_genomes"][i+1]]
      # else:
      #   couple_genomes = [sp["parent_genomes"][i], sp["parent_genomes"][i]]
      var number_of_offspring_each_couple = int(round((1.0 / SELECTION_RATE) * 2.0))
      var couple_crossovered_genomes = couple_crossover(couple_genomes,
          number_of_offspring_each_couple)
      crossovered_genomes.append_array(couple_crossovered_genomes)
  return crossovered_genomes

func couple_crossover(couple_genomes: Array, offspring_number: int) -> Array:
  random.randomize()
  var crossovered_genomes := []
  var fittest_parent
  var weakest_parent
  if couple_genomes[0]["fitness"] > couple_genomes[1]["fitness"]:
    fittest_parent = couple_genomes[0]
    weakest_parent = couple_genomes[1]
  else:
    fittest_parent = couple_genomes[1]
    weakest_parent = couple_genomes[0]

  for _i in offspring_number:
    var crossed_genome := {}

    # inherit nodes inherit from the fittest parent
    crossed_genome["input_nodes"] = []
    for input_node in fittest_parent["input_nodes"]:
      crossed_genome["input_nodes"].append(input_node)
    crossed_genome["output_nodes"] = []
    for output_node in fittest_parent["output_nodes"]:
      crossed_genome["output_nodes"].append(output_node)
    crossed_genome["hidden_nodes"] = []
    for hidden_node in fittest_parent["hidden_nodes"]:
      crossed_genome["hidden_nodes"].append(hidden_node)
    crossed_genome["links"] = []

    var weakest_parent_ids = []
    for link in weakest_parent["links"]:
      weakest_parent_ids.append(link["id"])
    for link in fittest_parent["links"]:
      if link["id"] in weakest_parent_ids: # matching links, random selection
        if random.randf() > 0.5:
          crossed_genome["links"].append(link)
        else:
          for wl in weakest_parent["links"]:
            if wl["id"] == link["id"]:
              crossed_genome["links"].append(wl)
      else: # excess or disjoint links, from the fittest
        crossed_genome["links"].append(link)

    crossovered_genomes.append(crossed_genome)
  return crossovered_genomes


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


func link_already_exists(_genome, source_node, target_node):
  if target_node.has("incoming_link_ids"): # Because it can be an input node in the recursion
    # This checks if the link we want to create already exists, not if it's circular
    for link_id in target_node["incoming_link_ids"]:
      # find the source of the link with this id
      var link := {}
      for l in _genome["links"]:
        if l["id"] == link_id:
          link = l
      if link["source_id"] == source_node["id"]:
        return true
  return false

func is_circular_loop(_genome, source_node, target_node):
  for link in _genome["links"]:
    if link["source_id"] == target_node["id"] && link["target_id"] == source_node["id"]:
      return true
    
  if target_node.has("outgoing_link_ids"): # Because it can be an output node as a candidate target
    for outlink_id in target_node["outgoing_link_ids"]:
      var outlink := {}
      for l in _genome["links"]:
        if l["id"] == outlink_id:
          outlink = l
      # if outlink["target_id"] == source_node["id"]:
      #   return true

      # In order to recurse we first have to find the target node of the target_node when it is not the source node
      var candidate_target_nodes = _genome["hidden_nodes"]
      var target_of_the_target_node
      for node in candidate_target_nodes:
        if node["id"] == outlink["target_id"]:
          target_of_the_target_node = node # this can be null because the target of the link is an output node
      if target_of_the_target_node != null && is_circular_loop(_genome, source_node, target_of_the_target_node):
        return true
  return false

func choose_target_node(genome_source_node, _genome):
  var candidate_nodes = _genome["hidden_nodes"] + _genome["output_nodes"]
  # breakpoint
  var unlinked_nodes = []
  for node in candidate_nodes:
    var is_node_linked := false
    if node["id"] == genome_source_node["id"]:
      is_node_linked = true
    elif is_circular_loop(_genome, genome_source_node, node) or link_already_exists(_genome, genome_source_node, node):
      is_node_linked = true
    if !is_node_linked:
      unlinked_nodes.append(node)
  if !unlinked_nodes.empty():
    var target_node
    while target_node == null:
      for node in unlinked_nodes:
        if random.randf() < float(1.0 / unlinked_nodes.size()):
          target_node = node
          break
    return target_node
  else:
    return null

func mutate(parent_genomes):
  if parent_genomes.size() == 0:
    print("No parents. Starting over...")
    return []
  random.randomize()
  var mutated_genomes = parent_genomes.duplicate(true)
  # var mutated_genomes = parent_genomes.duplicate()
  for _genome in mutated_genomes:
    # var genes_number = float(_genome["links"].size()) \
    #     + float(_genome["input_nodes"].size()) \
    #     + float(_genome["output_nodes"].size()) \
    #     + float(_genome["hidden_nodes"].size())
    if random.randf() < MUTATION_RATE:
      for link in _genome["links"]:
        # Shift weights and biases
        if random.randf() < 0.5:
          # if random.randf() < EXPECTED_MUTATED_GENES / genes_number:
          if random.randf() < EXPECTED_MUTATED_GENE_RATE:
            link["weight"] = random.randfn(link["weight"], MUTATION_STANDARD_DEVIATION)
          if random.randf() < EXPECTED_MUTATED_GENE_RATE:
            link["bias"] = random.randfn(link["bias"], MUTATION_STANDARD_DEVIATION)
        # Change weights and biases randomly
        else:
          if random.randf() < EXPECTED_MUTATED_GENE_RATE:
            link["weight"] = random.randf_range(-ORIGINAL_WEIGHT_VALUE_LIMIT, ORIGINAL_WEIGHT_VALUE_LIMIT)
          if random.randf() < EXPECTED_MUTATED_GENE_RATE:
            link["bias"] = random.randfn(-ORIGINAL_BIAS_VALUE_LIMIT, ORIGINAL_BIAS_VALUE_LIMIT)
        if random.randf() < EXPECTED_MUTATED_GENE_RATE:
          link["is_enabled"] = !link["is_enabled"]
      # Add a link
      for genome_source_node in (_genome["input_nodes"] + _genome["hidden_nodes"]):
        if random.randf() < EXPECTED_MUTATED_GENE_RATE:
          var genome_target_node = choose_target_node(genome_source_node, _genome)
          if genome_target_node != null:
            var new_id = generate_UID()
            # check if there is a link with source and target the other way around
            # for link in _genome["links"]:
            #   if link["source_id"] == genome_target_node["id"] && link["target_id"] == genome_source_node["id"]:
            #     continue
            var new_link = {"id": new_id, "weight": random.randf_range(-1.0, 1.0),
                "bias": random.randf_range(-1.0, 1.0),
                "source_id": genome_source_node["id"],
                "target_id": genome_target_node["id"], "is_enabled": true}
            _genome["links"].append(new_link)
            genome_source_node["outgoing_link_ids"].append(new_link["id"])
            genome_target_node["incoming_link_ids"].append(new_link["id"])
      # add a new node and break the link
      if _genome["links"].size() == 0:
        continue # cannot break a link if there isn't one
      var link_to_break
      while link_to_break == null:
        for genome_link in _genome["links"]:
          if random.randf() < EXPECTED_MUTATED_GENE_RATE:
            link_to_break = genome_link
      link_to_break.is_enabled = false # original link disabled
      var original_source_node
      for genome_source_node in (_genome["input_nodes"] + _genome["hidden_nodes"]):
        if link_to_break["source_id"] == genome_source_node["id"]:
          original_source_node = genome_source_node
      var original_target_node
      for genome_target_node in (_genome["output_nodes"] + _genome["hidden_nodes"]):
        if link_to_break["target_id"] == genome_target_node["id"]:
          original_target_node = genome_target_node
      var new_hnode = {"id": generate_UID(),
          "incoming_link_ids": [],
          "outgoing_link_ids": []}
      _genome["hidden_nodes"].append(new_hnode) # create the new hidden node
      # create the new links for the new hidden node
      var link_a = {"id": generate_UID(),
          "source_id": original_source_node["id"],
          "target_id": new_hnode["id"],
          # "weight": random.randf_range(-1.0, 1.0), "bias": random.randf_range(-1.0, 1.0),
          "weight": 1.0, "bias":0.0,
          "is_enabled": true}
      # Main.used_node_ids.append(link_a["id"])
      var link_b = {"id": generate_UID(),
          "source_id": new_hnode["id"],
          "target_id": original_target_node["id"],
          "weight": link_to_break["weight"], "bias": link_to_break["bias"],
          "is_enabled": true}
      # Main.used_node_ids.append(link_b["id"])
      _genome["links"].append(link_a)
      _genome["links"].append(link_b)
      new_hnode["incoming_link_ids"].append(link_a["id"])
      new_hnode["outgoing_link_ids"].append(link_b["id"])
      original_source_node["outgoing_link_ids"].append(link_a["id"])
      original_target_node["incoming_link_ids"].append(link_b["id"])

  return mutated_genomes


func speciate():
  if !species.empty():
    for sp in species:
      sp["members"] = []
      sp["total_adjusted_fitness"] = 0
      sp["parent_genomes"] = []
  for genome in genomes:
    # get all the genome's nodes, ids and their max id
    var gen_all_nodes = genome["input_nodes"] + genome["hidden_nodes"] \
        + genome["output_nodes"] + genome["links"];
    var gen_all_ids = []
    for node in gen_all_nodes:
      gen_all_ids.append(node["id"])
    var gen_max_id = gen_all_ids.max()

    var is_different_species := true
    for sp in species:

    # get all the prototypes's nodes, ids and their max id
      var prot = sp["prototype"]
      var prot_all_nodes = prot["input_nodes"] + prot["hidden_nodes"] \
          + prot["output_nodes"] + prot["links"]
      var prot_all_ids = []
      for node in prot_all_nodes:
        prot_all_ids.append(node["id"])
      var prot_max_id = prot_all_ids.max()

      var N = max(gen_max_id, prot_max_id) # find N
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
      var avg_weight_diff := 0.0
      if weight_diffs.size() != 0:
        for weight_diff in weight_diffs:
          weight_diffs_sum += weight_diff
        avg_weight_diff = weight_diffs_sum / weight_diffs.size() # find average weight differences

      var compatibility_distance = ((C1 * excess_genes_num) / N) \
          + ((C2 * disjoined_genes_num) / N) \
          + (C3 * avg_weight_diff)
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
  max_id_used += 1
  # return used_node_ids.max() + 1 
  return max_id_used


# func add_UID_in_used(id):
#   if id > used_node_ids.max():
#     used_node_ids.append(id)
  # if id > 



class GenomeSorter:
  static func sort_ascenting(a, b):
    if a["fitness"] < b["fitness"]:
      return true
    return false
