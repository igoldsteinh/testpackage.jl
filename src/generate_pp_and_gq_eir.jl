function generate_pp_and_gq_eir(samples, 
    data_cases,
    obstimes,
    param_change_times,
    seed::Int64 = 1,
    gamma_sd::Float64 = 0.2,
    gamma_mean::Float64 =log(1/4),
    nu_sd::Float64 = 0.2,
    nu_mean::Float64 = log(1/7),
    rho_case_sd::Float64= 1.0,
    rho_case_mean::Float64 = 0.0,
    phi_sd::Float64 = 0.2,
    phi_mean::Float64 = log(50),
    I_init_sd::Float64 = 0.05,
    I_init_mean::Float64 = 489.0,
    E_init_sd::Float64 = 0.05,
    E_init_mean::Float64 = 225.0,
    sigma_rt_sd::Float64 = 0.2,
    sigma_rt_mean::Float64 = log(0.1),
    rt_init_sd::Float64 = 0.1,
    rt_init_mean::Float64 = log(0.88))
  obstimes = convert(Vector{Float64}, obstimes)
  outs_tmp = dualcache(zeros(6,length(1:obstimes[end])), 10)


  my_model = bayes_eir_closed!(outs_tmp, 
                            data_cases, 
                            obstimes, 
                            param_change_times,
                            gamma_sd,
                            gamma_mean,
                            nu_sd,
                            nu_mean,
                            rho_case_sd,
                            rho_case_mean,
                            phi_sd,
                            phi_mean,
                            I_init_sd,
                            I_init_mean,
                            E_init_sd,
                            E_init_mean,
                            sigma_rt_sd,
                            sigma_rt_mean,
                            rt_init_sd,
                            rt_init_mean)


  missing_data = repeat([missing], length(data))

  my_model_forecast_missing = bayes_eir_closed!(outs_tmp, 
                            missing_data, 
                            obstimes, 
                            param_change_times,
                            gamma_sd,
                            gamma_mean,
                            nu_sd,
                            nu_mean,
                            rho_case_sd,
                            rho_case_mean,
                            phi_sd,
                            phi_mean,
                            I_init_sd,
                            I_init_mean,
                            E_init_sd,
                            E_init_mean,
                            sigma_rt_sd,
                            sigma_rt_mean,
                            rt_init_sd,
                            rt_init_mean)

  # remove samples which are NAs
  indices_to_keep = .!isnothing.(generated_quantities(my_model, samples));

  samples_randn = ChainsCustomIndex(samples, indices_to_keep);


  Random.seed!(seed)
  predictive_randn = predict(my_model_forecast_missing, samples_randn)

  Random.seed!(seed)
  gq_randn = Chains(generated_quantities(my_model, samples_randn))

  samples_df = DataFrame(samples)

  results = [DataFrame(predictive_randn), DataFrame(gq_randn), samples_df]
  return(results)
end