#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import division # no more "zero" integer division bugs!:P
import sys
import argparse
import os
import numpy as np # array
import h5py
import random
import constants as cst # local constants module
from scipy.stats import norm as scipy_norm
import ancillary as anc
from matplotlib import use as mpluse
mpluse("Agg")
#mpluse("Qt4Agg")
import matplotlib.pyplot as plt
plt.rc('font',**{'family':'serif','serif':['Computer Modern Roman']})
plt.rc('text', usetex=True)
#from matplotlib import rcParams
#rcParams['text.latex.unicode']=True
#import corner


def main():

  print 
  print ' ======================== '
  print ' TRADES+EMCEE CHAIN PLOTS'
  print ' ======================== '
  print

  # read cli arguments
  cli = anc.get_args()
  # computes mass conversion factor
  #m_factor, m_unit = anc.mass_conversion_factor_and_unit(cli.m_type)
  m_factor, m_unit = anc.mass_type_factor(1., cli.m_type, False)

  # set emcee and trades folder
  emcee_folder = cli.full_path
  trades_folder = os.path.join(os.path.dirname(cli.full_path), '')
  # and best folder
  emcee_file, emcee_best, folder_best = anc.get_emcee_file_and_best(emcee_folder, cli.temp_status)

  parameter_names_emcee, parameter_boundaries, chains, acceptance_fraction, autocor_time, lnprobability, ln_err_const, completed_steps = anc.get_data(emcee_file, cli.temp_status)

  # set label and legend names
  kel_labels = anc.keplerian_legend(parameter_names_emcee, cli.m_type)

  nfit, nwalkers, nruns, npost, nruns_sel = anc.get_emcee_parameters(chains, cli.temp_status, cli.npost, completed_steps)

  anc.print_memory_usage(chains)

  chains_T_full, parameter_boundaries = anc.select_transpose_convert_chains(nfit, nwalkers, npost, nruns, nruns_sel, m_factor, parameter_names_emcee, parameter_boundaries, chains)

  chains_T, flatchain_posterior_0, lnprob_burnin, thin_steps = anc.thin_the_chains(cli.use_thin, npost, nruns, nruns_sel, autocor_time, chains_T_full, lnprobability, burnin_done=True)
  
  
  #name_par, name_excluded = anc.get_sample_list(cli.sample_str, parameter_names_emcee)
  #sample_parameters, idx_sample = anc.pick_sample_parameters(flatchain_posterior_0, parameter_names_emcee, name_par = name_par, name_excluded = name_excluded)

  flatchain_posterior_1 = flatchain_posterior_0

  if(cli.boot_id > 0):
    flatchain_posterior_msun = anc.posterior_back_to_msun(m_factor,parameter_names_emcee,flatchain_posterior_0)
    boot_file = anc.save_bootstrap_like(emcee_folder, cli.boot_id, parameter_names_emcee, flatchain_posterior_msun)
    logger.info('saved bootstrap like file: %s' %(boot_file))
    del flatchain_posterior_msun

  #median_parameters, median_perc68, median_confint = anc.get_median_parameters(flatchain_posterior_0)

  k = np.ceil(2. * flatchain_posterior_0.shape[0]**(1./3.)).astype(int)
  if(k>50): k=50
  #mode_bin, mode_parameters, mode_perc68, mode_confint = anc.get_mode_parameters_full(flatchain_posterior_0, k)
  
  # max lnprob
  #max_lnprob, max_lnprob_parameters, max_lnprob_perc68, max_lnprob_confint = anc.get_maxlnprob_parameters(lnprob_burnin, chains_T, flatchain_posterior_0)
  #print 
  
  ## OPEN summary_parameters.hdf5 FILE
  s_h5f = h5py.File(os.path.join(cli.full_path, 'summary_parameters.hdf5'), 'r')
  # sample_parameters
  ci_fitted = s_h5f['confidence_intervals/fitted/ci'][...]
  sample_parameters = s_h5f['parameters/0666/fitted/parameters'][...]
  median_parameters = s_h5f['parameters/1050/fitted/parameters'][...]
  max_lnprob_parameters = s_h5f['parameters/2050/fitted/parameters'][...]
  mode_parameters = s_h5f['parameters/3050/fitted/parameters'][...]
  s_h5f.close()

  emcee_plots = os.path.join(cli.full_path,'plots')
  if (not os.path.isdir(emcee_plots)):
    os.makedirs(emcee_plots)

  for i in range(0, nfit):
    if('Ms' in parameter_names_emcee[i]):
      conv_plot = m_factor
    else:
      conv_plot = 1.
    
    emcee_fig_file = os.path.join(emcee_plots, 'chain_%s.png' %(parameter_names_emcee[i].strip()))
    print ' %s' %(emcee_fig_file),
    fig, (axChain, axHist) = plt.subplots(nrows=1, ncols=2, figsize=(12,12))

    
    (counts, bins_val, patches) = axHist.hist(flatchain_posterior_1[:,i], bins=k, range=(flatchain_posterior_1[:,i].min(), flatchain_posterior_1[:,i].max()), orientation='horizontal', normed=True, stacked=True, histtype='stepfilled', color='darkgrey', edgecolor='lightgray', align='mid')

    xpdf = scipy_norm.pdf(flatchain_posterior_1[:,i], loc = flatchain_posterior_1[:,i].mean(), scale = flatchain_posterior_1[:,i].std())
    idx = np.argsort(flatchain_posterior_1[:,i])
    axHist.plot(xpdf[idx], flatchain_posterior_1[idx,i], color='black', marker='None', ls='-.', lw=1.5, label='pdf')

    axChain.plot(chains_T[:,:,i], '-', alpha=0.3)

    # plot of mode (mean of higher peak/bin)
    axChain.axhline(mode_parameters[i]*conv_plot, color='red', ls='-', lw=2.1, alpha=1, label='mode')
    
    # plot of median
    axChain.axhline(median_parameters[i]*conv_plot, marker='None', c='blue',ls='-', lw=2.1, alpha=1.0, label='median fit')
    
    # plot of max_lnprob
    axChain.axhline(max_lnprob_parameters[i]*conv_plot, marker='None', c='black',ls='-', lw=2.1, alpha=1.0, label='max lnprob')
    
    if(sample_parameters is not None):
      # plot of sample_parameters
      axChain.axhline(sample_parameters[i]*conv_plot, marker='None', c='orange',ls='--', lw=2.3, alpha=0.77, label='picked: %12.7f' %(sample_parameters[i]))
      
    # plot ci
    axChain.axhline(ci_fitted[i,0]*conv_plot, marker='None', c='forestgreen',ls='-', lw=2.1, alpha=1.0, label='CI 15.865th')
    axChain.axhline(ci_fitted[i,1]*conv_plot, marker='None', c='forestgreen',ls='-', lw=2.1, alpha=1.0, label='CI 84.135th')
    
    axChain.ticklabel_format(useOffset=False)
    xlabel = '$N_\mathrm{steps}$'
    if(cli.use_thin):
      xlabel = '$N_\mathrm{steps} \\times %d$' %(thin_steps)
    axChain.set_xlabel(xlabel)
    axChain.set_ylabel(kel_labels[i])
    
    y_min, y_max = anc.compute_limits(flatchain_posterior_1[:,i], 0.05)
    if(y_min == y_max):
      y_min = parameter_boundaries[i,0]
      y_max = parameter_boundaries[i,1]
    
    axChain.set_ylim([y_min, y_max])
    axChain.set_title('Full chain %s:=[%.3f , %.3f]' %(kel_labels[i], parameter_boundaries[i,0], parameter_boundaries[i,1]))
    plt.draw()

    axHist.ticklabel_format(useOffset=False)
    axHist.set_ylim([y_min, y_max])

    # plot mode
    axHist.axhline(mode_parameters[i]*conv_plot, color='red', ls='-', lw=2.1, alpha=1, label='mode')
    # plot median
    axHist.axhline(median_parameters[i]*conv_plot, marker='None', c='blue',ls='-', lw=2.1, alpha=1.0, label='median fit')
    # plot of max_lnprob
    axHist.axhline(max_lnprob_parameters[i]*conv_plot, marker='None', c='black',ls='-', lw=2.1, alpha=1.0, label='max lnprob')
    
    if(sample_parameters is not None):
      # plot of sample_parameters
      axHist.axhline(sample_parameters[i]*conv_plot, marker='None', c='orange',ls='--', lw=2.3, alpha=0.77, label='picked: %12.7f' %(sample_parameters[i]*conv_plot))
      
    # plot ci
    axHist.axhline(ci_fitted[i,0]*conv_plot, marker='None', c='forestgreen',ls='-', lw=2.1, alpha=1.0, label='CI 15.865th')
    axHist.axhline(ci_fitted[i,1]*conv_plot, marker='None', c='forestgreen',ls='-', lw=2.1, alpha=1.0, label='CI 84.135th')
    
    axHist.set_title('Distribution of posterior chain')
    axHist.legend(loc='center left', fontsize=9, bbox_to_anchor=(1, 0.5))
    plt.draw()

    fig.savefig(emcee_fig_file, bbox_inches='tight', dpi=150)
    print ' saved'
    print

  fig = plt.figure(figsize=(12,12))
  plt.plot(lnprob_burnin.T, '-', alpha=0.8)
  plt.xlabel('$N_\mathrm{steps}$')
  plt.ylabel('logprob')
  min_lnp = np.min(lnprob_burnin.T, axis=0).min()
  max_lnp = np.max(lnprob_burnin.T, axis=0).max()
  y_min, y_max = anc.compute_limits(np.asarray([min_lnp, max_lnp]), 0.05)
  plt.ylim((y_min, y_max))
  plt.draw()
  fig.savefig(os.path.join(emcee_plots, 'emcee_lnprobability.png'), bbox_inches='tight', dpi=150)
  print ' %s saved' %(os.path.join(emcee_plots, 'emcee_lnprobability.png'))

  return

if __name__ == "__main__":
  main()




