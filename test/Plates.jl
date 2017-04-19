@testset "Plate" begin
    @testset "Singular Interactions" begin
        N = 100
        zs = rand(Complex128, N)
        δ  = rand()

        sheet = Vortex.Sheet(zs, cumsum(rand(N)), δ)
        Γs = [b.Γ for b in sheet.blobs]

        points = Vortex.Point.(zs, Γs)
        blobs = Vortex.Blob.(zs, Γs, δ)

        plate = Vortex.Plate(128, 2.0, rand(Complex128), 0.5π*rand())

        vel_s = zeros(Complex128, plate.N)
        vel_p = zeros(Complex128, plate.N)
        vel_b = zeros(Complex128, plate.N)

        Vortex.induce_velocity!(vel_s, plate, sheet)
        Vortex.induce_velocity!(vel_p, plate, points)
        Vortex.induce_velocity!(vel_b, plate, blobs)

        @test vel_s == vel_b
        @test vel_p == vel_b
    end
    @testset "Chebyshev Transform" begin
        const cheb! = Vortex.Plates.chebyshev_transform!

        N = rand(128:512)

        R = zeros(Float64, N)
        @test all(rand(0:(N÷2), 10)) do n
            x = [cos(n*θ) for θ in linspace(π, 0, N)]
            cheb!(R, x)
            (R[n+1] ≈ 1.0) && (sum(R) ≈ 1.0)
        end

        n₁ = rand(0:(N÷2))
        n₂ = rand(0:(N÷2))
        x₁ = [cos(n₁*θ) for θ in linspace(π, 0, N)]
        x₂ = [cos(n₂*θ) for θ in linspace(π, 0, N)]

        C = x₁ .+ im.*x₂
        I = zeros(Float64, N)

        cheb!(R, x₁)
        cheb!(I, x₂)
        cheb!(C)

        @test real.(C) ≈ R
        @test imag.(C) ≈ I

        plan! = FFTW.plan_r2r!(C, FFTW.REDFT00)
        @allocated cheb!(C, plan!)
        @test 0 == (@allocated cheb!(C, plan!))
    end

    @testset "Bound Circulation" begin
        include("utils/circle_plane.jl")

        c = rand(Complex128)
        ċ = rand(Complex128)
        α = 0.5π*rand()
        α̇ = rand()
        c = rand(Complex128)
        ċ = rand(Complex128)
        α = 0.5π*rand()
        α̇ = rand()

        N = 10
        ζs = (2 .+ rand(N)).*exp.(2π.*rand(N))
        zs = c .+ 0.5.*exp(im*α).*(ζs .+ 1./ζs)
        Γs = 1 .- 2.*rand(N)

        Np = 128
        J = JoukowskyMap(c, α)

        Δż_circle = map(linspace(π, 0, Np)) do θ
            η₊ = exp.(im*θ)
            η₋ = conj.(η₊)

            ż₋ = W_vortex(η₋, ζs, Γs) + W_motion(η₋, ċ, α, α̇)
            ż₊ = W_vortex(η₊, ζs, Γs) + W_motion(η₊, ċ, α, α̇)

            ż₊ = conj(ż₊/J(η₊, 1))
            ż₋ = conj(ż₋/J(η₋, 1))

            exp(-im*α).*(ż₋ .- ż₊)
        end;       
        @test norm(imag.(Δż_circle[2:end-1])) ≤ 1e-10

        points = Vortex.Point.(zs, Γs)
        plate = Vortex.Plate(Np, 2.0, c, α, ċ, α̇)
        Vortex.Plates.enforce_no_flow_through!(plate, points)
        γs = zeros(Float64, Np)
        Vortex.Plates.bound_circulation!(γs, plate)
        @test maximum(abs2.(γs[2:end-1] .- real.(Δż_circle[2:end-1]))) ≤ 256eps()

    end

    @testset "Induced Velocities" begin
    c = rand(Complex128)
    ċ = rand(Complex128)
    α = 0.5π*rand()
    α̇ = rand()
    
    J = JoukowskyMap(c, α)
    N = 100
    ζs = (2 .+ rand(N)).*exp.(2π.*rand(N))
    zs = J.(ζs)
    Γs = 1 .- 2.*rand(N)

    Np = 128
    Nt = 256

    ζt = 10.0.*exp.(im.*linspace(0, 2π, Nt))
    zt = J.(ζt)

    ż_circle = map(ζt) do ζ
    ż = W_vortex(ζ, ζs, Γs) + W_motion(ζ, ċ, α, α̇)
    conj(ż/J(ζ, 1))
    end

    points = Vortex.Point.(zs, Γs)
    plate = Vortex.Plate(Np, 2.0, c, α, ċ, α̇)
    Vortex.Plates.enforce_no_flow_through!(plate, points)

    sys = (plate, points)
    żs = Vortex.induce_velocity(zt, sys)
    @test ż_circle ≈ żs
    end

    @testset "Suction Parameters" begin
        U = rand()
        α = rand()*0.5π
        L = 2rand()
        plate = Vortex.Plate(128, L, 0.0, α, U)
        point = Vortex.Point(-Inf, 1.0);
        _, Γ, _, _ = Vortex.Plates.vorticity_flux(plate, point, point, Inf, 0)

        @test Γ ≈ -π*U*L*sin(α)
    end
end