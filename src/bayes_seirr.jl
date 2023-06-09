"""
    bayes_seirr(data_log_copies, ...)
Turing model for the SEIRR model 

default priors are for scenario 1, and assume the model is being fit to a daily time scale
      
      
# Arguments 
-`data_log_copies::Float64`: Log RNA concentrations  
-`obstimes::Float64`: times cases are observed
-`param_change_times::Float64`: times when the reproduction number is allowed to change
-`extra_ode_precision::Boolean`: if true, uses custom ode precisions, otherwise uses default values 
-`prob`: DifferentialEquations ODEProblem 
-`fit_abs_tol::Float64 = 1e-9`: if `extra_ode_precision` true, absolute tolerance for model fitting 
-`fit_rel_tol::Float64 = 1e-6`: if `extra_ode_precision` true, relative tolerance for model fitting 
-`opt_abs_tol::Float64 = 1e-11`: if `extra_ode_precision` true, absolute tolerance for choosing mcmc initial values 
-`opt_rel_tol::Float64 = 1e-8`: if `extra_ode_precision` true, relative tolerance for choosing mcmc initial values
-`popsize::Int64 = 100000`: population size
-`active_pop::Int64 = 90196`: population size - initial size of R compartment
-`gamma_sd::Float64 = 0.2`: standard deviation for normal prior of log gamma 
-`gamma_mean::Float64 =log(1/4)`: mean for normal prior of log gamma 
-`nu_sd::Float64 = 0.2`: standard deviation for normal prior of log nu
-`nu_mean::Float64 = log(1/7)`: mean for normal prior of log nu
-`eta_sd::Float64 = 0.2`: standard deviation for normal prior of log eta 
-`eta_mean::Float64 = log(1/18)`: mean for normal prior of log eta 
-`rho_gene_sd::Float64= 1.0`: standard devation for normal prior of log rho 
-`rho_gene_mean::Float64 = 0.0`: mean for normal prior of log rho 
-`tau_sd::Float64 = 1.0`: standard deviation for normal prior of log tau
-`tau_mean::Float64 = 0.0`: mean for normal prior of log tau
-`S_SEIR1_sd::Float64 = 0.05`: standard deviation for normal prior on logit fraction of `active_pop` initially in S
-`S_SEIR1_mean::Float64 = 3.468354`: mean for normal prior on logit fraction of `active_pop` initially in S
-`I_EIR1_sd::Float64 = 0.05`: standard deviation for normal prior on logit fraction of initial E,I and R1 compartments in the I compartment 
-`I_EIR1_mean::Float64 = -1.548302`: mean for normal prior on logit fraction of initial E,I and R1 compartments in the I compartment 
-`R1_ER1_sd::Float64 = 0.05`: standard deviation for normal prior on logit fraction of initial E and R1 compartments in the R1 compartment 
-`R1_ER1_mean::Float64 = 2.221616`: mean for normal prior on logit fraction of initial E and R1 compartments in the R1 compartment 
-`sigma_R0_sd::Float64 = 0.2`: standard deviation for normal prior of log sigma R0
-`sigma_R0_mean::Float64 = log(0.1)`: mean for normal prior of log sigma R0
-`r0_init_sd::Float64 = 0.1`: standard deviation for normal prior of log R0
-`r0_init_mean::Float64 = log(0.88)`: mean for normal prior of log R0
-`lambda_mean::Float64 = 5.685528`: mean for normal prior of logit lambda 
-`lambda_sd::Float64 = 2.178852`: standard deviation for normal prior of logit lambda 
-`df_shape::Float64 = 2.0`: shape parameter for gamma prior of df
-`df_scale::Float64 = 10.0`: scale parameter for gamma prior of df 

"""

@model function bayes_seirr(data_log_copies, 
                                    obstimes, 
                                    param_change_times, 
                                    extra_ode_precision, 
                                    prob, 
                                    abs_tol, 
                                    rel_tol,
                                    popsize::Int64 = 100000,
                                    active_pop::Int64 = 92271,
                                    gamma_sd::Float64 = 0.2,
                                    gamma_mean::Float64 =log(1/4),
                                    nu_sd::Float64 = 0.2,
                                    nu_mean::Float64 = log(1/7),
                                    eta_sd::Float64 = 0.2,
                                    eta_mean::Float64 = log(1/18),
                                    rho_gene_sd::Float64 =  1.0,
                                    rho_gene_mean::Float64 = 0.0,
                                    tau_sd::Float64 = 1.0,
                                    tau_mean::Float64 = 0.0,
                                    sigma_R0_sd::Float64 = 0.2,
                                    sigma_R0_mean::Float64 = log(0.1),
                                    S_SEIR1_sd::Float64 = 0.05,
                                    S_SEIR1_mean::Float64 = 3.468354,
                                    I_EIR1_sd::Float64 = 0.05,
                                    I_EIR1_mean::Float64 = -1.548302,
                                    R1_ER1_sd::Float64 = 0.05,
                                    R1_ER1_mean::Float64 = 2.221616,
                                    r0_init_sd::Float64 = 0.2,
                                    r0_init_mean::Float64 = log(0.88),
                                    lambda_mean::Float64 = 5.685528,
                                    lambda_sd::Float64 = 2.178852,
                                    df_shape::Float64 = 2.0,
                                    df_scale::Float64 = 10.0)
    # Calculate number of observed datapoints timepoints
    # shift = 1 # shift should always be one because ode indexes by 0 but julia indexes by 1, so that S[1] = S(0) in the ODE solution
    l_copies = length(obstimes)
    l_param_change_times = length(param_change_times)
  
    # Priors
    R0_params_non_centered ~ MvNormal(zeros(l_param_change_times + 2), Diagonal(ones(l_param_change_times + 2))) # +2, 1 for var, 1 for init
    S_SEIR1_non_centered ~ Normal()
    I_EIR1_non_centered ~ Normal()
    R1_ER1_non_centered ~ Normal()
    gamma_non_centered ~ Normal() # rate to I
    nu_non_centered ~ Normal() # rate to R1
    eta_non_centered ~ Normal() # rate to R2
    rho_gene_non_centered ~ Normal() # gene detection rate
    τ_non_centered ~ Normal() # standard deviation for log scale data
    lambda_non_centered ~ Normal() # percentage of emissions from the I vs R1 compartment
    df ~ Gamma(df_shape, df_scale)
  
    # Transformations
    gamma = exp(gamma_non_centered * gamma_sd + gamma_mean)
    nu = exp(nu_non_centered * nu_sd + nu_mean)
    eta = exp(eta_non_centered * eta_sd + eta_mean)
  
    rho_gene = exp(rho_gene_non_centered * rho_gene_sd + rho_gene_mean)
  
    τ = exp(τ_non_centered * tau_sd + tau_mean)
    lambda = logistic(lambda_non_centered * lambda_sd + lambda_mean)
  
    sigma_R0_non_centered = R0_params_non_centered[1]
  
    sigma_R0 = exp(sigma_R0_non_centered * sigma_R0_sd + sigma_R0_mean)
  
    r0_init_non_centered = R0_params_non_centered[2]
  
    r0_init = exp(r0_init_non_centered * r0_init_sd + r0_init_mean)
    beta_init = r0_init * nu
  
    log_R0_steps_non_centered = R0_params_non_centered[3:end]
  
    S_SEIR1 = logistic(S_SEIR1_non_centered * S_SEIR1_sd + S_SEIR1_mean)
    I_EIR1 = logistic(I_EIR1_non_centered * I_EIR1_sd + I_EIR1_mean)
    R1_ER1 = logistic(R1_ER1_non_centered * R1_ER1_sd + R1_ER1_mean)
  
    S_init = S_SEIR1 * active_pop
    I_init = max(I_EIR1 * (active_pop - S_init), 1) # Make sure at least 1 Infectious
    R1_init = max(R1_ER1 * (active_pop - S_init - I_init), 1) # Make sure at least 1 Infection
    E_init = max(active_pop - (S_init + I_init + R1_init), 1) # Make sure at least 1 Exposed
    u0 = [S_init, E_init, I_init, R1_init, 1.0, I_init] # Intialize with 1 in R2 so there are no problems when we log for ODE
    log_u0 = log.(u0)
    p0 = [beta_init, gamma, nu, eta]

    # Time-varying parameters
    beta_t_values_no_init = exp.(log(r0_init) .+ cumsum(vec(log_R0_steps_non_centered) * sigma_R0)) * nu
    beta_t_values_with_init = vcat(beta_init, beta_t_values_no_init)
  
  
    function param_affect_beta_IFR!(integrator)
      ind_t = searchsortedfirst(param_change_times, integrator.t) # Find the index of param_change_times that contains the current timestep
      integrator.p[1] = beta_t_values_no_init[ind_t] # Replace beta with a new value from beta_t_values
    end
  
    param_callback = PresetTimeCallback(param_change_times, param_affect_beta_IFR!, save_positions = (false, false))
  
    # Solve the ODE  at obstimes
    if extra_ode_precision
      sol = solve(prob, Tsit5(), callback = param_callback, saveat = 1.0, save_start = true, verbose = false, abstol = abs_tol, reltol = rel_tol,
      u0=log_u0, 
      p=p0, 
      tspan=(0.0, obstimes[end]))   
    else
      sol = solve(prob, Tsit5(), callback = param_callback, saveat = 1.0, save_start = true, verbose = false,
      u0=log_u0, 
      p=p0, 
      tspan=(0.0, obstimes[end])) 
    end
      
    # If the ODE solver fails, reject the sample by adding -Inf to the likelihood
    if sol.retcode != :Success
      Turing.@addlogprob! -Inf
      return
    end
  
    sol_reg_scale_array = exp.(Array(sol))
  
  
    # cases_pos_mean = (exp.(α_t_values_with_init) .* sol_new_cases / popsize) ./ (expm1.(α_t_values_with_init) .* sol_new_cases / popsize .+ 1)
  
    log_genes_mean = log.(sol_reg_scale_array[3,2:end] .* lambda + (1 - lambda) .* sol_reg_scale_array[4, 2:end]) .+ log(rho_gene) # first entry is the initial conditions, we want 2:end
    new_cases = sol_reg_scale_array[6, 2:end] - sol_reg_scale_array[6, 1:(end-1)]
  
    for i in 1:l_copies
      index = obstimes[i] # what time in the ode matches the obs time?
      data_log_copies[i] ~ GeneralizedTDist(log_genes_mean[round(Int64,index)], τ, df) 
    end
  
    # Generated quantities
    S = sol_reg_scale_array[1, :]
    r0_t_values_with_init = beta_t_values_with_init / nu
    R0_full_values = zeros(Real, round(Int64,obstimes[end]))
    # shifted_change_times = param_change_times .+ shift
    # ok here's the idea 
    # Rt is actually a function of the S compartment, it changes subtly as S changes, even though R0 is flat for a particular week
    # so for reach flat week of R0, we should still get 7 different values of Rt because of the changes in S
    # r0_t_values_with_init = ones(length(param_change_times) + 1)
    for i in 1:(round(Int64,obstimes[end]))
        # print(floor(Int64, i/7))
        R0_full_values[i] = r0_t_values_with_init[floor(Int64, (i-1)/7) + 1]

        # if (i == round(Int64, obstimes[end]))
        # print(i)
        # print(floor(Int64, (i-1)/7) + 1)
        # print(ForwardDiff.value(R0_full_values[i]))
        # end 
    end 
    
    # there are too many Rt values if we use all of S b/c S[1] is 0
    # and what we need is S[133] = 132 for the time period (132,133]
    Rt_t_values = R0_full_values .* S[1:end-1] / popsize
  
    return (
      gamma = gamma,
      nu = nu,
      eta = eta,
      rho_gene = rho_gene,
      r0_init = r0_init,
      sigma_R0 = sigma_R0, 
      τ = τ,
      lambda = lambda, 
      df = df,
      beta_t_values = beta_t_values_with_init,
      r0_t_values = r0_t_values_with_init,
      R0_full_values,
      rt_t_values = Rt_t_values,
      S_SEIR1,
      I_EIR1,
      R1_ER1,
      S_init,
      E_init,
      I_init,
      R1_init,
      S = sol_reg_scale_array[1, :],
      E = sol_reg_scale_array[2, :],
      I = sol_reg_scale_array[3, :],
      R1 = sol_reg_scale_array[4, :],
      R2 = sol_reg_scale_array[5, :],
      new_cases = new_cases,
      log_genes_mean = log_genes_mean
    )
  end
  