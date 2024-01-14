class_name Population

const C1 := 0.5
const C2 := 0.5
const C3 := 0.4
const dt := 0.22 # distance

const Species = preload("res://scripts/species.gd")

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


# Changes genomes to the next generation
func next_generation(agents: Array):
  initialize_genomes_with_fitness(agents) # Initializes genomes array with fitness values only
  speciate() # Categorizes genomes into species
  share_fitness_all_species() # Fills the adjusted_fitness in all genomes
  select_in_all_species(agents.size()) # Fills the parent_genomes in all species
  genomes = crossover_all_species(species)
  mutate_all_genomes()


func mutate_all_genomes():
  for genome in genomes:
    genome.mutate()


func crossover_all_species(_species: Array) -> Array:
  var do_parents_exist := false
  for sp in _species:
    if sp["parent_genomes"].size() > 0:
      do_parents_exist = true
      break
  if !do_parents_exist:
    return []
  var crossovered_genomes := []
  for sp in _species:
    crossovered_genomes.append_array(sp.crossover())
  return crossovered_genomes


# Fills the adjusted_fitness in all genomes
func share_fitness_all_species():
  for sp in species:
    sp.share_fitness()


# Fills the parent_genomes in all species
func select_in_all_species(agents_size):
  for sp in species:
    sp.select_in_species(agents_size * selection_rate)


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


# Initializes genomes array with fitness values only
func initialize_genomes_with_fitness(agents: Array):
  var _genomes = []
  for agent in agents:
    agent.get_fitness()
    _genomes.append(agent.genome.duplicate())
  genomes = _genomes


# Categorizes genomes into species
func speciate():
  if !species.empty():
    for sp in species:
      sp.reset_species()

  for genome in genomes:
    # get all the genome's nodes, ids and their max id
    var gen_all_genes = genome.input_nodes + genome.hidden_nodes \
        + genome.output_nodes + genome.links
    var gen_all_ids = []
    for gene in gen_all_genes:
      gen_all_ids.append(gene.id)
    var gen_max_id = gen_all_ids.max()

    var is_different_species := true
    for sp in species:
    # get all the prototypes's nodes, ids and their max id
      var prot = sp.prototype
      var prot_all_genes = prot.input_nodes + prot.hidden_nodes \
          + prot.output_nodes + prot.links
      var prot_all_ids = []
      for gene in prot_all_genes:
        prot_all_ids.append(gene.id)
      var prot_max_id = prot_all_ids.max()

      var N = max(gen_all_genes.size(), prot_all_genes.size()) # find N
      # TOTRY (good perfomance)
      # if N < 20:
      #   N = 1

      # Find disjoint and excess genes
      var min_id = min(gen_max_id, prot_max_id)
      var disjoint_genes_num = 0
      var excess_genes_num = 0
      var weight_diffs = []
      for genome_n in gen_all_genes:
        if !prot_all_ids.has(genome_n.id) and genome_n.id <= min_id:
          disjoint_genes_num += 1 #find disjoint genes
        elif !prot_all_ids.has(genome_n.id) and genome_n.id > min_id:
          excess_genes_num += 1 # find excess genes

        for prot_n in prot_all_genes:
          if prot_n.weight != null && prot_n.id == genome_n.id:
            assert(genome_n.weight != null,
                "Error in change_generation(). pron_n is a link while genome_n isn't")
            weight_diffs.append(abs(prot_n.weight - genome_n.weight))
      var weight_diffs_sum := 0.0
      var avg_weight_diff := 0.0
      if weight_diffs.size() > 0:
        for weight_diff in weight_diffs:
          weight_diffs_sum += weight_diff
        avg_weight_diff = weight_diffs_sum / weight_diffs.size() # find average weight differences

      var compatibility_distance = ((C1 * excess_genes_num) / N) \
          + ((C2 * disjoint_genes_num) / N) \
          + (C3 * avg_weight_diff)
      if compatibility_distance < dt:
        is_different_species = false
        sp.members.append(genome)
        break # we don't want a genome to belong to 2 different species
    if is_different_species || species.empty():
      add_species(genome)

func add_species(genome):
  var sp = Species.new(genome, [genome])
  species.append(sp)

