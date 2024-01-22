class_name Population

const C1 := 0.5
const C2 := 0.5
const C3 := 0.4
const dt := 1.0 # distance, original 0.35

const Species = preload("res://scripts/species.gd")
const Genome = preload("res://scripts/genome.gd")

var genomes
var species

var selection_rate
var target_population

var random = RandomNumberGenerator.new()
var max_IN_used := 0
var generation := 0
var all_species_adj_fitness = 0.0


func _init(_genomes=[], _species=[], _selection_rate=0.3, _target_population=100):
  genomes = _genomes
  species = _species
  selection_rate = _selection_rate
  target_population = _target_population

  random.randomize()


# Creates and initializes all genomes with input and output nodes
func init_genomes(input_names: Array, output_names: Array, number_of_genomes: int):
  for _i in range(0, number_of_genomes):
    var new_genome = Genome.new(self)
    new_genome.init_io_nodes(input_names, output_names)
    # new_genome.gen_num = 0
    genomes.append(new_genome)


# Changes genomes to the next generation
func next_generation(agents: Array):
  initialize_genomes_with_fitness(agents) # Initializes genomes array with fitness values only
  speciate() # Categorizes genomes into species
  share_fitness_all_species() # Fills the adjusted_fitness in all genomes
  select_in_all_species(target_population) # Fills the parent_genomes in all species, calcs avg_fitness
  genomes = crossover_all_species()
  mutate_all_genomes()
  increment_generation()


# Initializes genomes array with fitness values only
func initialize_genomes_with_fitness(agents: Array):
  var _genomes = []
  for agent in agents:
    agent.get_fitness()
    _genomes.append(agent.genome)
  genomes = _genomes.duplicate()


func mutate_all_genomes():
  for genome in genomes:
    genome.mutate()


func crossover_all_species() -> Array:
  var do_parents_exist := false
  for sp in species:
    if sp.parent_genomes.size() > 0:
      do_parents_exist = true
      break
  if !do_parents_exist:
    return []
  var crossovered_genomes := []
  for sp in species:
    var noff = int(floor(sp.population_fraction * target_population))
    crossovered_genomes.append_array(sp.crossover(noff))
  return crossovered_genomes

func cross_species(pop):
  var crossovered_genomes := []
  var noff_remainder := 0.0
  for sp in species:
    var real_noff = sp.population_fraction * pop
    var noff = int(floor(real_noff))
    noff_remainder += real_noff - noff
    crossovered_genomes.append_array(sp.crossover(noff))
  if noff_remainder >= 1.0:
    crossovered_genomes.append_array(cross_species(int(floor(noff_remainder))))
  return crossovered_genomes


# Fills the adjusted_fitness in all genomes
func share_fitness_all_species():
  for sp in species:
    sp.share_fitness()


# Fills the parent_genomes in all species
func select_in_all_species(total_pop):
  for sp in species:
    # Calculate the avg_fitness and append it to the array
    sp.calculate_avg_fitness()
  calculate_all_species_adj_fitness()
  distribute_parents(total_pop * selection_rate)
  kill_empty_species()
  fill_parent_genomes()

func distribute_parents(total_parents):
  var parents_num_remainder = 0.0
  for sp in species:
    sp.parent_genomes = []
  for sp in species:
    sp.population_fraction = sp.total_adjusted_fitness / all_species_adj_fitness
    var real_p_num = sp.population_fraction * total_parents
    parents_num_remainder += real_p_num - floor(real_p_num)
    var parents_number = int(floor(real_p_num))
    sp.select_in_species(parents_number)
  if parents_num_remainder >= 1.0:
    distribute_parents(parents_num_remainder)

func calculate_all_species_adj_fitness():
  all_species_adj_fitness = 0.0
  for sp in species:
    all_species_adj_fitness += sp.total_adjusted_fitness
  return all_species_adj_fitness

func kill_empty_species():
  var species_to_erase = []
  for sp in species:
    if sp.parent_genomes.size() == 0 || sp.members.size() == 0:
      species_to_erase.append(sp)
  for sp_to_erase in species_to_erase:
    for member in sp_to_erase.members:
      member.gen_num = -1
    species.erase(sp_to_erase) # remove any species with zero members or parent members

func fill_parent_genomes():
  var species_with_parent_genomes_left := false
  for sp in species:
    if sp.parent_genomes.size() > 0:
      species_with_parent_genomes_left = true
      break
  if !species_with_parent_genomes_left:
    print("zero parents error")
    return
  var total_parents := 0
  for sp in species:
    total_parents += sp.parent_genomes.size()
  while total_parents * (1.0 / selection_rate) < target_population:
    for sp in species:
      if sp.parent_genomes.size() > 0 && random.randf() < 1.0 / species.size():
        sp.parent_genomes.append(sp.members[-1])
        total_parents += 1


# Categorizes genomes into species
func speciate():
  if !species.empty():
    for sp in species:
      sp.reset_species()

  for genome in genomes:
    var closest_species = {"cd": INF}
    # get all the genome's nodes, innovation numberss and their max IN
    var gen_all_genes = genome.input_nodes + genome.hidden_nodes \
        + genome.output_nodes + genome.links
    var gen_all_inno_nums = []
    for gene in gen_all_genes:
      gen_all_inno_nums.append(gene.inno_num)
    var gen_max_inno_num = gen_all_inno_nums.max()

    var is_different_species := true
    for sp in species:
    # get all the prototypes's nodes, INs and their max IN
      var prot = sp.prototype
      var prot_all_genes = prot.input_nodes + prot.hidden_nodes \
          + prot.output_nodes + prot.links
      var prot_all_inno_nums = []
      var prot_all_link_inno_nums = []
      for gene in prot_all_genes:
        prot_all_inno_nums.append(gene.inno_num)
      for link in prot.links:
        prot_all_link_inno_nums.append(link.inno_num)
      var prot_max_inno_num = prot_all_inno_nums.max()

      var N = max(gen_all_genes.size(), prot_all_genes.size()) # find N
      # TOTRY (good perfomance)
      # if N < 15:
      #   N = 1

      # Find disjoint and excess genes
      var min_inno_num = min(gen_max_inno_num, prot_max_inno_num)
      var disjoint_genes_num = 0
      var excess_genes_num = 0
      var weight_diffs = []
      var disjoint_gene_INs = []
      var excess_gene_INs = []
      for genome_n in gen_all_genes:
        if !prot_all_inno_nums.has(genome_n.inno_num) and genome_n.inno_num <= min_inno_num:
          disjoint_gene_INs.append(genome_n.inno_num)
          disjoint_genes_num += 1 #find disjoint genes
        elif !prot_all_inno_nums.has(genome_n.inno_num) and genome_n.inno_num > min_inno_num:
          excess_genes_num += 1 # find excess genes
          excess_gene_INs.append(genome_n.inno_num)

        for prot_n in prot_all_genes:
          # if prot_n.weight != null && prot_n.id == genome_n.id:
          # if "weight" in prot_n && prot_n.id == genome_n.id:
          # if prot_all_link_inno_nums.has(prot_n.inno_num):
          #   print("Oh Lawd Yeah!")
          if prot_all_link_inno_nums.has(prot_n.inno_num) && prot_n.inno_num == genome_n.inno_num:
            assert(genome_n.weight != null,
                "Error in change_generation(). pron_n is a link while genome_n isn't")
            weight_diffs.append(abs(prot_n.weight - genome_n.weight))

      for prot_n in prot_all_genes:
        if !gen_all_inno_nums.has(prot_n.inno_num) and prot_n.inno_num <= min_inno_num and !(prot_n.inno_num in disjoint_gene_INs):
          disjoint_gene_INs.append(prot_n.inno_num)
          disjoint_genes_num += 1 #find disjoint genes
        elif !gen_all_inno_nums.has(prot_n.inno_num) and prot_n.inno_num > min_inno_num and !(prot_n.inno_num in disjoint_gene_INs): 
          excess_genes_num += 1 # find excess genes
          excess_gene_INs.append(prot_n.inno_num)

      var weight_diffs_sum := 0.0
      var avg_weight_diff := 0.0
      if weight_diffs.size() > 0:
        for weight_diff in weight_diffs:
          weight_diffs_sum += weight_diff
        avg_weight_diff = weight_diffs_sum / weight_diffs.size() # find average weight differences

      var compatibility_distance = ((C1 * excess_genes_num) / N) \
          + ((C2 * disjoint_genes_num) / N) \
          + (C3 * avg_weight_diff)
      # if compatibility_distance < dt && compatibility_distance < closest_species["cd"] && !(genome.gen_num == sp.creation_gen):
      #   print("gen_num = %s, creation_gen = %s" % [genome.gen_num, sp.creation_gen])
      if genome.gen_num == -1:
        print("It's -1")
      if species.size() > 14:
        print("Species: more than 14")
      var compatibility_distance_limit
      if species.size() > 2:
        compatibility_distance_limit = dt + ((species.size()-1) * 0.015) * pow(species.size()-1, 2)
      else:
        compatibility_distance_limit = dt
      if compatibility_distance < compatibility_distance_limit && compatibility_distance < closest_species["cd"] \
            && (genome.gen_num == sp.creation_gen || genome.gen_num == -1): # -1 means these are orphaned genomes
        is_different_species = false
        closest_species = {"species": sp, "cd": compatibility_distance}
        # break # we don't want a genome to belong to 2 different species
    if !is_different_species && !species.empty():
      add_member_to_species(closest_species["species"], genome)
    elif is_different_species || species.empty():
      add_new_species(genome)

func add_new_species(genome):
  var sp = Species.new(self, genome, [genome])
  genome.tint = sp.tint
  genome.gen_num = sp.creation_gen
  species.append(sp)

func add_member_to_species(sp, genome):
  sp.members.append(genome)
  genome.gen_num = sp.creation_gen
  genome.tint = sp.tint
  # genome.comp_distance = cd


func generate_UIN():
  max_IN_used += 1
  return max_IN_used


func add_UIN(inno_num):
  if inno_num > max_IN_used:
    max_IN_used = inno_num
  return inno_num


func increment_generation():
  generation += 1
