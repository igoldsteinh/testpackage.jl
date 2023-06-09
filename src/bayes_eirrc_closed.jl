#bayesian alpha model eirr
"""
    bayes_eirrc_closed!(outs_tmp, ...)
Turing model for the EIRR model. 

default priors are for scenario 1, and assume the model is being fit to a daily time scale

# Arguments 
-`outs_tmp`: preallocated matrix used to store ODE solutions, created using the dualcache function from https://github.com/SciML/PreallocationTools.jl
-`data_log_copies::Float64`: Log RNA concentrations
-`obstimes::Float64`: times RNA concentrations are observed
-`param_change_times::Float64`: times when the reproduction number is allowed to change
-`priors_only::Boolean`: if TRUE function produces draws from the joint prior distribution
-`gamma_sd::Float64 = 0.2`: standard deviation for normal prior of log gamma 
-`gamma_mean::Float64 =log(1/4)`: mean for normal prior of log gamma 
-`nu_sd::Float64 = 0.2`: standard deviation for normal prior of log nu
-`nu_mean::Float64 = log(1/7)`: mean for normal prior of log nu
-`eta_sd::Float64 = 0.2`: standard deviation for normal prior of log eta 
-`eta_mean::Float64 = log(1/18)`: mena for normal prior of log eta 
-`rho_gene_sd::Float64= 1.0`: standard devation for normal prior of log rho 
-`rho_gene_mean::Float64 = 0.0`: mean for normal prior of log rho 
-`tau_sd::Float64 = 1.0`: standard deviation for normal prior of log tau
-`tau_mean::Float64 = 0.0`: mean for normal prior of log tau 
-`I_init_sd::Float64 = 0.05`: standard deviation for normal prior of I_init
-`I_init_mean::Float64 = 489.0`: mean for normal prior of I_init 
-`R1_init_sd::Float64 = 0.05`: standard deviation for normal prior of R1_init 
-`R1_init_mean::Float64 = 2075.0`: mean for normal prior of R1_init 
-`E_init_sd::Float64 = 0.05`: standard deviation for normal prior of E_init 
-`E_init_mean::Float64 = 225.0`: mean for normal prior of E_init 
-`lambda_mean::Float64 = 5.685528`: mean for normal prior of logit lambda 
-`lambda_sd::Float64 = 2.178852`: standard deviation for normal prior of logit lambda 
-`df_shape::Float64 = 2.0`: shape parameter for gamma prior of df
-`df_scale::Float64 = 10.0`: scale parameter for gamma prior of df 
-`sigma_rt_sd::Float64 = 0.2`: standard deviation for normal prior on log sigma rt 
-`sigma_rt_mean::Float64 = log(0.1)`: mean for normal prior on log sigma rt 
-`rt_init_sd::Float64 = 0.1`: standard deviation for normal prior on log rt_init 
-`rt_init_mean::Float64 = log(0.88)`: mean for normal prior on log rt_init 

"""

@model function bayes_eirrc_closed!(outs_tmp,
                                    data_log_copies, 
                                    obstimes, 
                                    param_change_times,
                                    gamma_sd::Float64 = 0.2,
                                    gamma_mean::Float64 =log(1/4),
                                    nu_sd::Float64 = 0.2,
                                    nu_mean::Float64 = log(1/7),
                                    eta_sd::Float64 = 0.2,
                                    eta_mean::Float64 = log(1/18),
                                    rho_gene_sd::Float64= 1.0,
                                    rho_gene_mean::Float64 = 0.0,
                                    tau_sd::Float64 = 1.0,
                                    tau_mean::Float64 = 0.0,
                                    I_init_sd::Float64 = 0.05,
                                    I_init_mean::Float64 = 489.0,
                                    R1_init_sd::Float64 = 0.05,
                                    R1_init_mean::Float64 = 2075.0,
                                    E_init_sd::Float64 = 0.05,
                                    E_init_mean::Float64 = 225.0,
                                    lambda_mean::Float64 = 5.685528,
                                    lambda_sd::Float64 = 2.178852,
                                    df_shape::Float64 = 2.0,
                                    df_scale::Float64 = 10.0,
                                    sigma_rt_sd::Float64 = 0.2,
                                    sigma_rt_mean::Float64 = log(0.1),
                                    rt_init_sd::Float64 = 0.1,
                                    rt_init_mean::Float64 = log(0.88)
)
  # Calculate number of observed datapoints timepoints
  l_copies = length(obstimes)
  l_param_change_times = length(param_change_times)

  # Priors
  rt_params_non_centered ~ MvNormal(zeros(l_param_change_times + 2), Diagonal(ones(l_param_change_times + 2))) # +2, 1 for var, 1 for init
  I_init_non_centered ~ Normal()
  R1_init_non_centered ~ Normal()
  E_init_non_centered ~ Normal()
  gamma_non_centered ~ Normal() # rate to I
  nu_non_centered ~ Normal() # rate to Re
  eta_non_centered ~ Normal() # rate to Rd
  rho_gene_non_centered ~ Normal() # gene detection rate
  tau_non_centered ~ Normal() # standard deviation for log scale data
  lambda_non_centered ~ Normal() # percentage of emissions from the I vs Re compartment
  df ~ Gamma(df_shape, df_scale)

  # Transformations
  gamma = exp(gamma_non_centered * gamma_sd + gamma_mean)
  nu = exp(nu_non_centered * nu_sd + nu_mean)
  eta = exp(eta_non_centered * eta_sd + eta_mean)

  rho_gene = exp(rho_gene_non_centered * rho_gene_sd + rho_gene_mean)

  tau = exp(tau_non_centered * tau_sd + tau_mean)
  lambda = logistic(lambda_non_centered * lambda_sd + lambda_mean)

  sigma_rt_non_centered = rt_params_non_centered[1]

  sigma_rt = exp(sigma_rt_non_centered * sigma_rt_sd + sigma_rt_mean)

  rt_init_non_centered = rt_params_non_centered[2]

  rt_init = exp(rt_init_non_centered * rt_init_sd + rt_init_mean)
  # rt_init = 0.945
  alpha_init = rt_init * nu

  log_rt_steps_non_centered = rt_params_non_centered[3:end]

  I_init = I_init_non_centered * I_init_sd + I_init_mean
  R1_init = R1_init_non_centered * R1_init_sd + R1_init_mean
  E_init = E_init_non_centered * E_init_sd + E_init_mean
  u0 = [E_init, I_init, R1_init, 1.0, 1.0] # Intialize with 1 in R2 b/c it doesn't matter

  # Time-varying parameters
  alpha_t_values_no_init = exp.(log(rt_init) .+ cumsum(vec(log_rt_steps_non_centered) * sigma_rt)) * nu
  alpha_t_values_with_init = vcat(alpha_init, alpha_t_values_no_init)

  sol_reg_scale_array = new_eirrc_closed_solution!(outs_tmp, 1:obstimes[end], param_change_times, 0.0, alpha_t_values_with_init, u0, gamma, nu, eta)
  # print(" alpha is ")
  # print(ForwardDiff.value(alpha_t_values_with_init))
  # print(" I is ")
  # print(ForwardDiff.value(sol_reg_scale_array[3, 2:end]))
  # print(" R1 is ")
  # print(ForwardDiff.value(sol_reg_scale_array[4, 2:end]))
  log_genes_mean = NaNMath.log.(sol_reg_scale_array[3, 2:end] .* lambda + (1 - lambda) .* sol_reg_scale_array[4, 2:end]) .+ log(rho_gene) # first entry is the initial conditions, we want 2:end
  incid = sol_reg_scale_array[6, 2:end] - sol_reg_scale_array[6, 1:(end-1)]

  for i in 1:l_copies
    index = obstimes[i] # what time in the ode matches the obs time?
    data_log_copies[i] ~ GeneralizedTDist(log_genes_mean[round(Int64,index)], tau, df) 
    # data_log_copies[i] ~ Normal(log_genes_mean[round(Int64,index)], tau) 
end

  # Generated quantities
  rt_t_values_with_init = alpha_t_values_with_init/ nu

  return (
    gamma = gamma,
    nu = nu,
    eta = eta,
    rho_gene = rho_gene,
    rt_init = rt_init,
    sigma_rt = sigma_rt,
    tau = tau,
    lambda = lambda,
    df = df,
    alpha_t_values = alpha_t_values_with_init,
    rt_t_values = rt_t_values_with_init,
    E_init,
    I_init,
    R1_init,
    E = sol_reg_scale_array[2, :],
    I = sol_reg_scale_array[3, :],
    R1 = sol_reg_scale_array[4, :],
    R2 = sol_reg_scale_array[5, :],
    C = sol_reg_scale_array[6, :],
    incid = incid,
    log_genes_mean = log_genes_mean
  )
end
