### Prepares Tests ###

# Fetch packages.
using Catalyst, Statistics, StochasticDiffEq, Test

# Sets stable rng number.
using StableRNGs
rng = StableRNG(12345)

# Fetch test functions and networks.
include("../test_functions.jl")
include("../test_networks.jl")


### Basic Tests ###

# Compares simulations generated through Catalyst with those generated by manually created functions.
let
    # Manually declares SDEs to compare Catalyst-generated simulations to.
    catalyst_networks = []
    manual_networks = []
    u0_syms = []
    ps_syms = []

    function real_f_1(du, u, p, t)
        X1, X2, X3 = u
        p, k1, k2, k3, d = p
        du[1] = 2 * p - k1 * X1
        du[2] = k1 * X1 - k2 * X2 - k3 * X2
        du[3] = k2 * X2 + k3 * X2 - d * X3
    end
    function real_g_1(du, u, p, t)
        X1, X2, X3 = u
        p, k1, k2, k3, d = p
        du[1, 1] = 2 * sqrt(p)
        du[1, 2] = -sqrt(k1 * X1)
        du[1, 3] = 0
        du[1, 4] = 0
        du[1, 5] = 0
        du[2, 1] = 0
        du[2, 2] = sqrt(k1 * X1)
        du[2, 3] = -sqrt(k2 * X2)
        du[2, 4] = -sqrt(k3 * X2)
        du[2, 5] = 0
        du[3, 1] = 0
        du[3, 2] = 0
        du[3, 3] = sqrt(k2 * X2)
        du[3, 4] = sqrt(k3 * X2)
        du[3, 5] = -sqrt(d * X3)
    end
    push!(catalyst_networks, reaction_networks_standard[8])
    push!(manual_networks, (f = real_f_1, g = real_g_1, nrp = zeros(3, 5)))
    push!(u0_syms, [:X1, :X2, :X3])
    push!(ps_syms, [:p, :k1, :k2, :k3, :d])

    function real_f_2(du, u, p, t)
        X1, = u
        v, K, n, d = p
        du[1] = v / 10 + v * X1^n / (X1^n + K^n) - d * X1
    end
    function real_g_2(du, u, p, t)
        X1, = u
        v, K, n, d = p
        du[1, 1] = sqrt(v / 10 + v * X1^n / (X1^n + K^n))
        du[1, 2] = -sqrt(d * X1)
    end
    push!(catalyst_networks, reaction_networks_hill[6])
    push!(manual_networks, (f = real_f_2, g = real_g_2, nrp = zeros(1, 2)))
    push!(u0_syms, [:X1])
    push!(ps_syms, [:v, :K, :n, :d])

    function real_f_3(du, u, p, t)
        X1, X2, X3, X4, X5, X6, X7 = u
        k1, k2, k3, k4, k5, k6 = p
        du[1] = -k1 * X1 * X2 + k2 * X3
        du[2] = -k1 * X1 * X2 + k2 * X3
        du[3] = k1 * X1 * X2 - k2 * X3 - k3 * X3 * X4 + k4 * X5
        du[4] = -k3 * X3 * X4 + k4 * X5
        du[5] = k3 * X3 * X4 - k4 * X5 - k5 * X5 * X6 + k6 * X7
        du[6] = -k5 * X5 * X6 + k6 * X7
        du[7] = k5 * X5 * X6 - k6 * X7
    end
    function real_g_3(du, u, p, t)
        X1, X2, X3, X4, X5, X6, X7 = u
        k1, k2, k3, k4, k5, k6 = p
        fill!(du, 0)
        du[1, 1] = -sqrt(k1 * X1 * X2)
        du[1, 2] = sqrt(k2 * X3)
        du[2, 1] = -sqrt(k1 * X1 * X2)
        du[2, 2] = sqrt(k2 * X3)
        du[3, 1] = sqrt(k1 * X1 * X2)
        du[3, 2] = -sqrt(k2 * X3)
        du[3, 3] = -sqrt(k3 * X3 * X4)
        du[3, 4] = sqrt(k4 * X5)
        du[4, 3] = -sqrt(k3 * X3 * X4)
        du[4, 4] = sqrt(k4 * X5)
        du[5, 3] = sqrt(k3 * X3 * X4)
        du[5, 4] = -sqrt(k4 * X5)
        du[5, 5] = -sqrt(k5 * X5 * X6)
        du[5, 6] = sqrt(k6 * X7)
        du[6, 5] = -sqrt(k5 * X5 * X6)
        du[6, 6] = sqrt(k6 * X7)
        du[7, 5] = sqrt(k5 * X5 * X6)
        du[7, 6] = -sqrt(k6 * X7)
    end
    push!(catalyst_networks, reaction_networks_constraint[9])
    push!(manual_networks, (f = real_f_3, g = real_g_3, nrp = zeros(7, 6)))
    push!(u0_syms, [:X1, :X2, :X3, :X4, :X5, :X6, :X7])
    push!(ps_syms, [:k1, :k2, :k3, :k4, :k5, :k6])

    for (rn_catalyst, rn_manual, u0_sym, ps_sym) in zip(catalyst_networks, manual_networks, u0_syms, ps_syms)
        for factor in [1e-1, 1e0], repeat in 1:3
            # Set input values.
            u0_1 = rnd_u0(rn_catalyst, rng; factor, min = 100.0)
            ps_1 = rnd_ps(rn_catalyst, rng; factor, min = 0.01)
            u0_2 = map_to_vec(u0_1, u0_sym)
            ps_2 = map_to_vec(ps_1, ps_sym)

            # Check drift functions.
            dt = zeros(length(u0_1))
            rn_manual.f(dt, u0_2, ps_2, 0.0)
            @test dt ≈ f_eval(rn_catalyst, u0_1, ps_1, 0.0)

            # Check diffusion functions.
            duW = zeros(size(rn_manual.nrp))
            rn_manual.g(duW, u0_2, ps_2, 0.0)
            @test duW ≈ g_eval(rn_catalyst, u0_1, ps_1, 0.0)

            # Compares simulation with identical seed. 
            # Cannot test the third network (requires very fiddly parameters for CLE to be defined).
            if nameof(rn_catalyst) != :rnc9
                sprob_1 = SDEProblem(rn_catalyst, u0_1, (0.0, 1.0), ps_1)
                sprob_2 = SDEProblem(rn_manual.f, rn_manual.g, u0_2, (0.0, 1.0), ps_2; noise_rate_prototype = rn_manual.nrp)
                sol1 = solve(sprob_1, ImplicitEM(); seed = 1234)
                sol2 = solve(sprob_2, ImplicitEM(); seed = 1234)
                @test sol1[u0_sym] ≈ sol2.u
            end
        end
    end
end

# Checks that simulations for a large number of potential systems are completed (and don't error).
# (cannot solve as solution likely to go into negatives). 
let
    for rn in reaction_networks_all
        u0 = rnd_u0(rn, rng)
        ps = rnd_ps(rn, rng)
        sprob = SDEProblem(rn, u0, (0.0, 1.0), ps)
        init(sprob, ImplicitEM())
    end
end

### Noise Scaling ###

# Compares noise scaling with manually declared noise function. 
let 
    function real_g_3(du, u, P, t)
        X1, X2 = u
        η1, η2, p, k1, k2, d = P
        fill!(du, 0)
        du[1, 1] = η1 * sqrt(p)
        du[1, 2] = - η2 * sqrt(k1 * X1)
        du[1, 3] = (2 * η2 + 1) * sqrt(k2 * X2)
        du[1, 4] = 0.0
        du[2, 1] = 0.0 
        du[2, 2] = η2 * sqrt(k1 * X1)
        du[2, 3] = - (2 * η2 + 1) * sqrt(k2 * X2)
        du[2, 4] = 0.0
        return du
    end
    
    noise_scaling_network = @reaction_network begin 
        @parameters η1 η2
        @default_noise_scaling η1
        p, 0 --> X1
        (k1, k2), X1 ↔ X2, ([noise_scaling=η2],[noise_scaling=2 * η2 + 1]) 
        d, X2 --> 0, [noise_scaling = 0.0]
    end
    
    u0_1 = rnd_u0(noise_scaling_network, rng)
    ps_1 = rnd_ps(noise_scaling_network, rng)
    u0_2 = map_to_vec(u0_1, [:X1, :X2])
    ps_2 = map_to_vec(ps_1, [:η1, :η2, :p, :k1, :k2, :d])
    
    @test g_eval(noise_scaling_network, u0_1, ps_1, 0.0) == real_g_3(zeros(2, 4), u0_2, ps_2, 0.0)
end

# Tests with multiple noise scaling parameters directly in the macro.
let 
    noise_scaling_network_1 = @reaction_network begin 
        @parameters η1 η2
        (k1, k2), X1 ↔ X2, ([noise_scaling=η1],[noise_scaling=η2]) 
    end
    u0 = [:X1 => 1000.0, :X2 => 3000.0]
    sol_1_1 = solve(SDEProblem(noise_scaling_network_1, u0, (0.0, 1000.0), [:k1 => 2.0, :k2 => 0.66, :η1 => 2.0, :η2 => 2.0]), ImplicitEM(); saveat=1.0)
    sol_1_2 = solve(SDEProblem(noise_scaling_network_1, u0, (0.0, 1000.0), [:k1 => 2.0, :k2 => 0.66, :η1 => 2.0, :η2 => 0.2]), ImplicitEM(); saveat=1.0)
    sol_1_3 = solve(SDEProblem(noise_scaling_network_1, u0, (0.0, 1000.0), [:k1 => 2.0, :k2 => 0.66, :η1 => 0.2, :η2 => 0.2]), ImplicitEM(); saveat=1.0)
    @test var(sol_1_1[:X1]) > var(sol_1_2[:X1]) > var(sol_1_3[:X1]) 

    noise_scaling_network_2 = @reaction_network begin 
        @parameters η[1:2]
        (k1, k2), X1 ↔ X2, ([noise_scaling=η[1]],[noise_scaling=η[2]])  
    end
    @unpack k1, k2, η = noise_scaling_network_2
    sol_2_1 = solve(SDEProblem(noise_scaling_network_2, u0, (0.0, 1000.0), [k1 => 2.0, k2 => 0.66, η[1] => 2.0, η[2] => 2.0]), ImplicitEM(); saveat=1.0)
    sol_2_2 = solve(SDEProblem(noise_scaling_network_2, u0, (0.0, 1000.0), [k1 => 2.0, k2 => 0.66, η[1] => 2.0, η[2] => 0.2]), ImplicitEM(); saveat=1.0)
    sol_2_3 = solve(SDEProblem(noise_scaling_network_2, u0, (0.0, 1000.0), [k1 => 2.0, k2 => 0.66, η[1] => 0.2, η[2] => 0.2]), ImplicitEM(); saveat=1.0)
    @test var(sol_2_1[:X1]) > var(sol_2_2[:X1]) > var(sol_2_3[:X1]) 
end

# Tests using default values for noise scaling.
# Tests when reaction system is created programmatically.
# Tests @noise_scaling_parameters macro.
let
    η_stored = :η
    @variables t
    @species X1(t) X2(t)
    p_syms = @parameters $(η_stored) k1 k2

    r1 = Reaction(k1,[X1],[X2],[1],[1]; metadata = [:noise_scaling => η_stored])
    r2 = Reaction(k2,[X2],[X1],[1],[1]; metadata = [:noise_scaling => η_stored])
    @named noise_scaling_network = ReactionSystem([r1, r2], t, [X1, X2], [k1, k2, p_syms[1]])

    u0 = [:X1 => 1100.0, :X2 => 3900.0]
    p = [:k1 => 2.0, :k2 => 0.5, :η=>0.0]
    @test_broken SDEProblem(noise_scaling_network, u0, (0.0, 1000.0), p).ps[:η] == 0.0 # Broken due to SII/MTK stuff.
end

# Complicated test with many combinations of options.
# Tests the noise_scaling_parameters getter.
let
    noise_scaling_network = @reaction_network begin 
        @parameters k1 par1 [description="Parameter par1"] par2 η1 η2=0.0 [description="Parameter η2"] η3=1.0 η4
        (p, d), 0 ↔ X1, ([noise_scaling=η1],[noise_scaling=η2]) 
        (k1, k2), X1 ↔ X2, ([noise_scaling=η3],[noise_scaling=η4])  
    end
    u0 = [:X1 => 500.0, :X2 => 500.0]
    p = [:p => 20.0, :d => 0.1, :η1 => 0.0, :η3 => 0.0, :η4 => 0.0, :k1 => 2.0, :k2 => 2.0, :par1 => 1000.0, :par2 => 1000.0]
    
    @test getdescription(parameters(noise_scaling_network)[2]) == "Parameter par1"
    @test getdescription(parameters(noise_scaling_network)[5]) == "Parameter η2"
    
    sprob = SDEProblem(noise_scaling_network, u0, (0.0, 1000.0), p)
    @test sprob.ps[:η1] == sprob.ps[:η2] == sprob.ps[:η3] == sprob.ps[:η4] == 0.0
end

# Tests default_noise_scaling_option.
# Tests using sys. indexing for setting noise scaling parameter values.
# tests for default value used in noise scaling parameter.
let
    noise_scaling_network = @reaction_network begin
        @parameters η1 η2=0.1
        @default_noise_scaling η1
        (p,d), 0 <--> X1, ([noise_scaling=η2],[noise_scaling=η2])
        (p,d), 0 <--> X2, ([description="Y"],[description="Y"])
        (p,d), 0 <--> X3
    end
    
    u0 = [:X1 => 1000.0, :X2 => 1000.0, :X3 => 1000.0]
    ps = [noise_scaling_network.p => 1000.0, noise_scaling_network.d => 1.0, noise_scaling_network.η1 => 1.0]
    sol = solve(SDEProblem(noise_scaling_network, u0, (0.0, 1000.0), ps), ImplicitEM(); saveat=1.0)
    @test var(sol[:X1]) < var(sol[:X2]) 
    @test var(sol[:X1]) < var(sol[:X3]) 
end

# Tests  using complicated noise scaling expressions
let
    noise_scaling_network = @reaction_network begin
        @parameters η1 η2 η3 η4
        @species N1(t) N2(t)=0.5
        @variables N3(t)
        @default_noise_scaling η1 + N1 + 5.0
        p, 0 --> X1 
        p, 0 --> X2, [noise_scaling=0.33η2^1.2 + N2]
        p, 0 --> X3, [noise_scaling=N3*η3] 
        p, 0 --> X4, [noise_scaling=exp(-η4) - 0.008]
        p, 0 --> X5, [noise_scaling=0.0]
        d, (X1, X2, X3, X4, X5) --> 0, ([], [noise_scaling=0.33η2^1.2 + N2], [noise_scaling=N3*η3], [noise_scaling=exp(-η4) - 0.008], [noise_scaling=0.0])
    end

    u0 = [:X1 => 1000.0, :X2 => 1000.0, :X3 => 1000.0, :X4 => 1000.0, :X5 => 1000.0, :N1 => 3.0, :N3 => 0.33]
    ps = [:p => 1000.0, :d => 1.0, :η1 => 1.0, :η2 => 1.4, :η3 => 0.33, :η4 => 4.0]
    sol = solve(SDEProblem(noise_scaling_network, u0, (0.0, 1000.0), ps), ImplicitEM(); saveat=1.0, adaptive=false, dt=0.1)
    @test var(sol[:X1]) > var(sol[:X2]) > var(sol[:X3]) > var(sol[:X4]) > var(sol[:X5])
end

# Tests the `remake_noise_scaling` function.
let
    # Creates noise scaling networks.
    noise_scaling_network1 = @reaction_network begin
        p, 0 --> X, [noise_scaling=2.0]
        d, X --> 0
    end
    noise_scaling_network2 = set_default_noise_scaling(noise_scaling_network1, 0.5)

    # Checks that the two networks' reactions have the correct metadata.
    @test reactions(noise_scaling_network1)[1].metadata == [:noise_scaling => 2.0]
    @test reactions(noise_scaling_network1)[2].metadata == []
    @test reactions(noise_scaling_network2)[1].metadata == [:noise_scaling => 2.0]
    @test reactions(noise_scaling_network2)[2].metadata == [:noise_scaling => 0.5]
end

# Tests the `remake_noise_scaling` function on a hierarchical model.
let
    # Creates hierarchical model.
    rn1 = @reaction_network begin
        p, 0 --> X, [noise_scaling=2.0]
        d, X --> 0
    end
    rn2 = @reaction_network begin
        k1, X1 --> X2, [noise_scaling=5.0]
        k2, X2 --> X1
    end
    rn = compose(rn1, [rn2])

    # Checks that systems have the correct noise scaling terms.
    rn = set_default_noise_scaling(rn, 0.5)
    rn1_noise_scaling = [get_noise_scaling(rx) for rx in Catalyst.get_rxs(rn)]
    rn2_noise_scaling = [get_noise_scaling(rx) for rx in Catalyst.get_rxs(Catalyst.get_systems(rn)[1])]
    rn_noise_scaling = [get_noise_scaling(rx) for rx in reactions(rn)]
    @test issetequal(rn1_noise_scaling, [2.0, 0.5])
    @test issetequal(rn2_noise_scaling, [5.0, 0.5])
    @test issetequal(rn_noise_scaling, [2.0, 0.5, 5.0, 0.5])
end

### Checks Simulations Don't Error ###

#Tries to create a large number of problem, ensuring there are no errors (cannot solve as solution likely to go into negatives). 
let
    for reaction_network in reaction_networks_all
        for factor in [1e-2, 1e-1, 1e0, 1e1]
            u0 = factor * rand(rng, length(unknowns(reaction_network)))
            p = factor * rand(rng, length(parameters(reaction_network)))
            prob = SDEProblem(reaction_network, u0, (0.0, 1.0), p)
        end
    end
end

### Other Tests ###

# Tests simulating a network without parameters.
let
    no_param_network = @reaction_network begin (1.2, 5), X1 ↔ X2 end
    for factor in [1e3, 1e4]
        u0 = rnd_u0(no_param_network, rng; factor)
        prob = SDEProblem(no_param_network, u0, (0.0, 1000.0))
        sol = solve(prob, ImplicitEM())
        @test mean(sol[:X1]) > mean(sol[:X2])
    end
end
