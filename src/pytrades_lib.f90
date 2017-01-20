! TRADES fortran module to be called fron python

module pytrades
  use omp_lib
  use constants
  use parameters
  use parameters_conversion
  use convert_type,only:string
  use init_trades
  use derived_parameters_mod
  use transits,only:set_ephem
  use fitness_module
  use ode_run,only:orbits_to_data
  
  implicit none
  ! exposing variables in parameters to trades_lib
  !f2py integer,parameter::dp=selected_real_kind(8)
  !f2py character(512)::path
  !f2py integer::ndata,npar,nfit,dof
  !f2py real(dp),parameter::resmax=1.e10_dp
  
  !f2py integer::nRV,nRVset
  !f2py real(dp),dimension(:),allocatable::eRVobs ! it will be exposed in python as ervobs
  
  !f2py integer,dimension(:),allocatable::nT0
  !f2py real(dp),dimension(:,:),allocatable::eT0obs ! it will be exposed in python as et0obs
  
  !f2py real(dp)::ln_err_const
  
  !f2py real(dp),dimension(2,2)::MR_star
  !f2py real(dp),dimension(:),allocatable::system_parameters
  !f2py real(dp),dimension(:),allocatable::par_min,par_max ! dimension: system_parameters
  
  
  !f2py real(dp),dimension(:,:,:),allocatable::population
  !f2py real(dp),dimension(:,:),allocatable::population_fitness
  !f2py real(dp),dimension(:,:),allocatable::pso_best_evolution
  !f2py integer::seed_pso,np_pso,nit_pso,wrt_pso

  ! variables:  parameters to fit
  real(dp),dimension(:),allocatable::fitting_parameters
  real(dp),dimension(:,:),allocatable::parameters_minmax
  character(10),dimension(:),allocatable::parameter_names
  integer::n_global,n_bodies
  
   
  contains
  
  subroutine initialize_trades(path_in, sub_folder)
    !f2py real(dp),dimension(:),allocatable::eRVobs
    !f2py real(dp),dimension(:,:),allocatable::eT0obs
    character*(*),intent(in)::path_in, sub_folder
!     integer,intent(in)::n_threads_in
!     integer::n_threads
    real(dp),dimension(:),allocatable::m,R,P,a,e,w,mA,inc,lN
    integer,dimension(:),allocatable::nset
    character(80)::fmt
    
    ! subroutine: initu -> init_trades
    ! variables:  nfiles -> constants (default = 90)
    !             ncpu = 1
    call initu(nfiles, 1)
    
!     ! omp threads
!     n_threads=1
!     !$ call omp_set_num_threads(n_threads_in)
    
!     !$OMP parallel
!     !$ if(omp_get_thread_num().eq.0) n_threads = omp_get_num_threads()
!     !$OMP end parallel
!     write(*,*)' OMP NUMBER OF THREADS = ',n_threads

    
    
    ! IT READS THE COMMAND ARGUMENT THAT DEFINE THE PATH OF THE FOLDER WITH THE FILES
    ! subroutine: read_com_arg -> init_trades
    ! variables:  path -> parameters (default = empty)
    !call read_com_arg(path)
    path_0=trim(adjustl(path_in))
    path=trim(adjustl(path_in))
!     write(*,'(a,a)')" READING IN PATH = ",trim(path)
    
    ! IT DEFINES THE STRING TO WRITE THE REAL WITH RIGHT DECIMAL: PRECISION
    ! variables:  sprec -> constants
!     sprec="g27.15"
    sprec='es23.16'
    
    ! ---
    ! IT CALLS ALL THE SUBROUTINES TO READ ALL PARAMETERS AND DATA TO STORE IN COMMON MODULE PARAMETERS
    ! subroutine: read_first -> init_trades
    ! by scratch below:
    ! ---
    ! IT READS THE ARGUMENTS OF INTEGRATION AND STORE IN COMMON MODULE PARAMETERS.
    ! THE VARIBLES WILL NOT BE MODIFIED FURTHERMORE.
    ! subroutine: read_arg -> init_trades
    ! variables:  cpuid = 1
    call read_arg(1)
!     write(*,'(a,a,a)')" READ ",trim(path)//"arg.in"
!     progtype=6 ! needed for other subroutines
    
    ! variables:  e_bounds -> parameters
    !             NB -> parameters (default =2, updated with read_arg)
    n_bodies=NB ! needed to be used by python wrapper ... to check if I can avoid it
    allocate(e_bounds(2,NB))
    e_bounds(1,:)=TOLERANCE
    e_bounds(2,:)=1._dp-TOLERANCE
    ! IT READS THE FILES AND THE NAMES OF THE BODIES AND DETERMINES THE PARAMETERS TO BE FITTED
    ! subroutine: read_list -> init_trades
    ! variables:  cpuid = 1
    call read_list(1)
!     write(*,'(a,a,a)')" READ ",trim(path)//"bodies.lst"
    ! IT DEFINES THE ID OF THE PARAMETERS TO BE FITTED
    ! subroutine: idpar/idpar_fit -> init_trades
!     if(progtype.le.1)then
!       call idpar() ! IT DEFINES THE ID OF THE PARAMETERS TO BE FITTED
!     else
!       call idpar_fit()
!     end if
    call idpar()
    
    ! IT READS THE PARAMETERS FROM THE FILES
    ! subroutine: read_par -> init_trades
    ! variables:  cpuid=1
    !             m,R,P,a,e,w,mA,i,lN
!     call read_par(1,m,R,P,a,e,w,mA,i,lN)
!     ! IT READS BOUNDARIES OF THE KEPLERIAN ELEMENTS
!     ! subroutine: read_par_boundaries -> init_trades
!     ! variables:  cpuid=1
!     !             m,R
!     call read_par_boundaries(1,m,R) ! it sets minpar(nfit) and maxpar(nfit)
    call read_fullpar(1,m,R,P,a,e,w,mA,inc,lN,system_parameters)
    
    ! IT READS RV DATA
    ! variables:  nRV -> parameters
    nRV=0
    ! subroutine: read_RVobs -> init_trades
    ! variables:  cpuid=1
    call read_RVobs(1)
    ! function: string -> 
    ! variables:  rvcheck -> parameters
    !             nRVset -> parameters
    !             nRVsingle -> parameters
!     fmt=adjustl("(a,i4,a,i4,a,"//trim(string(nRVset))//"i4))")
!     if(rvcheck.eq.1) write(*,trim(fmt))" RV DATA: nRV = ",nRV,&
!       &" in ",nRVset," set of RV: ",nRVsingle

    ! IT READS T0 DATA
    ! subroutine: cpuid=1
    call read_T0obs(1)
    ! variables:  idtra -> parameters
    !             nT0 -> parameters
!     if(idtra.ne.0) write(*,'(a,1000(i5,1x))') " T0 DATA: nT0 = ",nT0(2:)

    ! IT SETS THE LINEAR EPHEMERIS FROM T0 DATA
    if(sum(nT0).gt.0) call set_ephem()

    ! IT DETERMINS THE NDATA
    ! variables:  ndata -> parameters
    !             dof -> parametershttp://www.r-bloggers.com/wilcoxon-signed-rank-test/
    !             nfit -> parameters
    !             inv_dof -> parameters
    !             one -> constants
    ndata=nRV+sum(nT0)
    
    if(nfit.ge.ndata)then
      stop('NUMBER OF PARAMETERS TO FIT IS GREATER/EQUAL TO TOTAL NUMBER OF DATAPOINTS')
    end if
    dof=(ndata-nfit)
    
    inv_dof = one / real(dof,dp)
!     write(*,'(a,i5)')" NUMBER OF DATA AVAILABLE: ndata = ",ndata
!     write(*,'(a,i5)')" NUMBER OF PARAMETERS TO FIT: nfit = ",nfit
!     write(*,'(a,i5)')&
!         &" NUMBER OF DEGREES OF FREEDOM : dof = ndata - nfit = ",dof

    ! IT DETERMINES THE LN_ERR_CONST TO COMPUTE LOGLIKELIHOOD
    ln_err_const = get_ln_err_const(eRVobs,eT0obs)
!     write(*,'(a,es23.16)')' LN_ERR_CONST (init_trades) = ',ln_err_const
!     flush(6)

    ! IT SETS THE LIST OF THE PARAMETERS TO FIT
    ! subroutine: set_parid_list -> init_trades
    call set_parid_list()
    ! IT SETS FITNESS PARAMETERS
    ! variables:  nset -> parameters
    !             k_a -> parameters
    !             k_b -> parameters
    if(nRV.ne.0.and.sum(nT0).ne.0)then
      allocate(nset(2),k_b(2))
      nset(1)=nRV
      nset(2)=sum(nT0)
    else if(nRV.ne.0.and.sum(nT0).eq.0)then
      allocate(nset(1),k_b(1))
      nset(1)=nRV
    else if(nRV.eq.0.and.sum(nT0).ne.0)then
      allocate(nset(1),k_b(1))
      nset(1)=sum(nT0)
    else
      stop('No data-set available. Please check the files.')
    end if
    ! PARAMETER TO PROPERLY SCALE THE RESIDUALS FOR THE CHI2
    k_a = sqrt(k_chi2r*inv_dof)
    ! PARAMETER TO PROPERLY SCALE THE RESIDUALS FOR THE CHI2_WEIGHTED
!     k_b = sqrt(k_chi2wr/real(dof,dp))*(real(ndata,dp)/real(nset,dp))
    k_b = sqrt((k_chi2wr*inv_dof)*(real(ndata,dp)/real(nset,dp)))
!     write(*,'(2(a,f7.4))')" k_chi2r = ",k_chi2r," k_chi2wr = ",k_chi2wr
!     if(size(nset).eq.2)then
!       write(*,'(a,i5,i5,a,f16.12,a,f16.12,f16.12)')" nset = ",nset," k_a = ",k_a," k_b = ",k_b
!     else if(size(nset).eq.1)then
!       write(*,'(a,i5,a,f16.12,a,f16.12)')" nset = ",nset," k_a = ",k_a," k_b = ",k_b
!     end if
    deallocate(nset)
    
    ! ---
    ! IT SETS THE VARIABLES system_parameters and par with fitting parameters
!     allocate(system_parameters(npar), fitting_parameters(nfit), parameters_minmax(nfit,2), parameter_names(nfit))
    allocate(parameters_minmax(nfit,2), parameter_names(nfit))
    
    ! subroutine: set_par -> init_trades
!     call set_par(m,R,P,a,e,w,mA,i,lN,system_parameters,fitting_parameters)
! !     call set_par(m,R,P,a,e,w,mA,i,lN,mc_allpar,par)
!     ! subroutine: fix_allpar -> init_trades
! !     call fix_system_parameters()
!     call fix_all_parameters(system_parameters)
!   
    call init_param(system_parameters,fitting_parameters)

    parameters_minmax(:,1)=minpar
    parameters_minmax(:,2)=maxpar
    parameter_names = parid
    
    ! check if there are derived parameters to compute and to check
    call init_derived_parameters(1,path)
    
    ! deallocated variables not needed anymore
    if(allocated(m)) deallocate(m,R,P,a,e,w,mA,inc,lN)
  
    path=trim(adjustl(path_in))//trim(adjustl(sub_folder))
!     write(*,'(a,a)')" RUNNING IN PATH = ",trim(path)
  
    return
  end subroutine initialize_trades
  
  subroutine init_fit_parameters(all_parameters,n_par,fit_parameters,n_fit)
    use parameters_conversion,only:init_param
    integer,intent(in)::n_par
    real(dp),dimension(n_par),intent(in)::all_parameters
    integer,intent(in)::n_fit
    real(dp),dimension(n_fit),intent(out)::fit_parameters
    
    real(dp),dimension(:),allocatable::temp_fit
  
    call init_param(all_parameters,temp_fit)
    fit_parameters = temp_fit
    if(allocated(temp_fit)) deallocate(temp_fit)
  
    return
  end subroutine init_fit_parameters
  
  
  subroutine init_pso(cpuid, path_in)
    integer,intent(in)::cpuid
    character(512),intent(in)::path_in
    character(512)::path_temp
    
    path_temp=trim(adjustl(path))
    path=trim(adjustl(path_in))
    call read_pso_opt(cpuid)
    n_global = nGlobal
    path=trim(adjustl(path_temp))

!     !$OMP parallel
!     !$ if(omp_get_thread_num().eq.0)  write(*,*)' OMP NUMBER OF THREADS = ', omp_get_num_threads()
!     !$OMP end parallel
    
    return
  end subroutine init_pso
  
  
  subroutine fortran_loglikelihood(fit_parameters, lgllhd, check, nfit)
    integer,intent(in)::nfit
    real(dp),dimension(nfit),intent(in)::fit_parameters
    real(dp),intent(out)::lgllhd
    logical,intent(out)::check
    real(dp)::fitness
    
    check=.true.
    fitness=zero
    
    fitness=bound_fitness_function(system_parameters,fit_parameters)
    lgllhd=-half*fitness*real(dof,dp) ! lgllh = - chi2 / 2 || fitness =~ chi2 / dof
    if(fitness.ge.resmax)check=.false.

    return
  end subroutine fortran_loglikelihood

  ! subroutine that output the fitness, check for given fit_parameters and global system_parameters
  subroutine fortran_fitness_short(fit_parameters, fitness, check, n_fit)
    integer,intent(in)::n_fit
    real(dp),dimension(n_fit),intent(in)::fit_parameters
    real(dp),intent(out)::fitness
    logical,intent(out)::check
    
    check=.true.
    fitness=zero
    fitness=bound_fitness_function(system_parameters,fit_parameters)
    if(fitness.ge.resmax)check=.false.
    
    return
  end subroutine fortran_fitness_short
  
  ! subroutine that output the fitness, check for given fit_parameters and updated all_parameters (instead of system_parameters)
!   subroutine fortran_fitness_long(fit_parameters, all_parameters, fitness, check, n_fit, n_par)
  subroutine fortran_fitness_long(all_parameters, n_par, fit_parameters, n_fit, fitness, check)
    integer,intent(in)::n_par
    real(dp),dimension(n_par),intent(in)::all_parameters
    integer,intent(in)::n_fit
    real(dp),dimension(n_fit),intent(in)::fit_parameters
    real(dp),intent(out)::fitness
    logical,intent(out)::check
    
    check=.true.
    fitness=zero
    fitness=bound_fitness_function(all_parameters,fit_parameters)
!     write(*,'(a,ES23.16)')' fitness = ',fitness
    if(fitness.ge.resmax)check=.false.
    
    return
  end subroutine fortran_fitness_long
  

!   subroutine write_summary_files(write_number,parameters_values,fitness,wrt_info,lgllhd,check,nfit)
!     use driver,only:write_summary_nosigma
! !     use ode_run,only:ode_out
! !     use output_files,only:write_parameters
!     integer,intent(in)::nfit
!     integer,intent(in)::write_number
!     real(dp),dimension(nfit),intent(in)::parameters_values
!     logical,intent(in),optional::wrt_info
!     real(dp),intent(out)::fitness,lgllhd
!     logical,intent(out)::check
!     real(dp),dimension(:),allocatable::run_all_par
!     logical::check_status
!     integer::i
!     
!     check=.true.
!     check_status=.true.
!     
!     write(*,'(a,l2)') 'check begin = ', check
! !     check=check_fit_boundaries(parameters_values)
!     if(present(wrt_info))then
!       check=check_only_boundaries(system_parameters,parameters_values,wrt_info)
!     else
!       check=check_only_boundaries(system_parameters,parameters_values)
!     end if
!   
!     if(check)then
!       write(*,'(a,l2)') 'check boundaries = ', check
!       allocate(run_all_par(npar))
!       run_all_par=system_parameters
!       if(check_derived) check_status=check_derived_parameters(parameters_values)
!       if(fix_derived) call fix_derived_parameters(parameters_values,run_all_par,check_status)
!       if(check_status)then
!         call write_summary_nosigma(1,write_number,0,run_all_par,parameters_values,fitness)
!       else
!         fitness=resmax ! set it to resmax
!         check=.false.
!       end if
!       deallocate(run_all_par)
!       
!     else
!       write(*,'(a,l2)') 'check boundaries = ', check
!       fitness=resmax
!     end if
!     lgllhd=-0.5_dp*fitness*real(dof,dp)
!     if(fitness.ge.resmax)check=.false.
!     
!     return
!   end subroutine write_summary_files

  subroutine write_summary_files(write_number,parameters_values,fitness,lgllhd,check,nfit)
    use driver,only:write_summary_nosigma
    integer,intent(in)::nfit
    integer,intent(in)::write_number
    real(dp),dimension(nfit),intent(in)::parameters_values
    real(dp),intent(out)::fitness,lgllhd
    logical,intent(out)::check
    real(dp),dimension(:),allocatable::run_all_par
    logical::check_status
    integer::i
!     logical::wrt_info=.true.
        
    check=.true.
    check_status=.true.
    
!     write(*,'(a,l2)') 'check begin = ', check
!     if(present(wrt_info).and.wrt_info)then
!     check=check_only_boundaries(system_parameters,parameters_values,wrt_info)
!     else
!       check=check_only_boundaries(system_parameters,parameters_values)
!     end if
    check=check_only_boundaries(system_parameters,parameters_values)
  
!     write(*,'(a,l2)') 'check boundaries = ', check
    allocate(run_all_par(npar))
    run_all_par=system_parameters
    if(check_derived) check_status=check_derived_parameters(parameters_values)
    if(fix_derived) call fix_derived_parameters(parameters_values,run_all_par,check_status)
    call write_summary_nosigma(1,write_number,0,run_all_par,parameters_values,fitness)
    deallocate(run_all_par)
    if(.not.check.or..not.check_status)then
      fitness=resmax
      write(*,'(a)')'*******'
      write(*,'(a)')'WARNING'
      write(*,'(a)')'WARNING'
      write(*,'(a)')'FITTED PARAMETERS COULD NOT BE PHYSICAL!'
      write(*,'(a)')'BE VERY CAREFUL WITH THIS PARAMETER SET!'
      write(*,'(a)')'WARNING'
      write(*,'(a)')'WARNING'
      write(*,'(a)')'*******'
    end if
    lgllhd=-0.5_dp*fitness*real(dof,dp)
!     if(fitness.ge.resmax)check=.false.

        
    return
  end subroutine write_summary_files
  
  
  subroutine write_summary_files_long(write_number,all_parameters,npar,parameters_values,nfit,fitness,lgllhd,check)
    use driver,only:write_summary_nosigma
!     use ode_run,only:ode_out
!     use output_files,only:write_parameters
    integer,intent(in)::npar
    real(dp),dimension(npar),intent(in)::all_parameters
    integer,intent(in)::nfit
    integer,intent(in)::write_number
    real(dp),dimension(nfit),intent(in)::parameters_values
    
    real(dp),intent(out)::fitness,lgllhd
    logical,intent(out)::check
    
    real(dp),dimension(:),allocatable::run_all_par
    logical::check_status
    integer::i
    
    check=.true.
    check_status=.true.
    
!     check=check_fit_boundaries(parameters_values)
    check=check_only_boundaries(system_parameters,parameters_values)
    
    if(check)then
      allocate(run_all_par(npar))
      run_all_par=all_parameters
      if(check_derived) check_status=check_derived_parameters(parameters_values)
      if(fix_derived) call fix_derived_parameters(parameters_values,run_all_par,check_status)
      if(check_status)then
        call write_summary_nosigma(1,write_number,0,run_all_par,parameters_values,fitness)
      else
        fitness=resmax ! set it to resmax
        check=.false.
      end if
      deallocate(run_all_par)
      
    else
      fitness=resmax
    end if
    lgllhd=-0.5_dp*fitness*real(dof,dp)
    if(fitness.ge.resmax)check=.false.
    
    return
  end subroutine write_summary_files_long
  
  ! pso
  subroutine pyrun_pso(nfit,i_global,best_parameters,best_fitness)
    use opti_pso,only:pso_driver,evaluate_pso
    integer,intent(in)::nfit
    integer,intent(in)::i_global
    real(dp),dimension(nfit),intent(out)::best_parameters
    real(dp),intent(out)::best_fitness
    real(dp)::best_inv_fitness
    integer::ii
    
    path=trim(adjustl(path))
    best_parameters=zero
    best_inv_fitness=one
    call pso_driver(i_global,evaluate_pso,nfit,system_parameters,minpar,maxpar,&
      &best_parameters,best_inv_fitness) ! PSO DRIVER
    best_fitness=one/best_inv_fitness

    return
  end subroutine pyrun_pso
  
  
  ! subroutine useful to modify the working path fo TRADES from python
  subroutine path_change(new_path)
    character(512),intent(in)::new_path
    path=trim(adjustl(new_path))
!     write(*,*)trim(adjustl(path))
    
    return
  end subroutine path_change

  ! init both cases for derived parameters
  ! 1)
  ! check if there are derived parameters to compute and to check
  subroutine init_check_parameters(cpuid,path_in)
    integer,intent(in)::cpuid ! cpu number: use 1
    character(512),intent(in)::path_in ! path of the folder with derived_boundaries.dat
    
    call init_check_derived_parameters(cpuid,path_in)
    
    return
  end subroutine init_check_parameters
  ! 2)
  ! check if there are derived parameters to compute and to check
  subroutine init_fix_parameters(n_derived_in,in_names,in_parameters)
    integer,intent(in)::n_derived_in
    character(15),dimension(n_derived_in),intent(in)::in_names
    real(dp),dimension(n_derived_in),intent(in)::in_parameters
    
    call init_fix_derived_parameters(n_derived_in,in_names,in_parameters)
    
    return
  end subroutine init_fix_parameters

  
  subroutine deallocate_variables()
  
    call deallocate_all() ! from 'parameters' module
    
    return
  end subroutine deallocate_variables
  
  
  
  ! SUBROUTINE TO INITIALISE TRADES WITHOUT READING FILES
  subroutine args_init(t_start,t_epoch,t_int,n_body,&
    &n_t0,t0_num,t0_obs,et0_obs,&
    &n_max_t0,n_col)
    
    ! INPUT
    ! t_start      == start of the integration
    ! t_epoch      == reference time epoch
    ! t_int        == total integration time in days
    ! n_body       == number of bodies (take into account the star)
    ! n_t0         == number of transits per each body n_t0(n_body); n_t0(0) = 0
    ! t0_num       == epochs/transit number for each body t0_num(n_max_t0,n_body); t0_num(:,0) = 0
    ! t0_obs       == transit times for each body t0_obs(n_max_t0,n_body); t0_obs(:,0) = 0
    ! et0_obs      == errors on the transit times in days for each body et0_obs(n_max_t0,n_body); et0_obs(:,0) = 0
    
    ! OUTPUT
    ! None ==> some variables set globally
    
    ! DIMENSIONS: do not provide it
    ! n_max_t0     == maxval(n_t0) == maxval of transits available
    
    
    integer::n_max_t0,n_col
    real(dp),intent(in)::t_start,t_epoch,t_int
    integer,intent(in)::n_body
    integer,dimension(n_col),intent(in)::n_t0
    integer,dimension(n_max_t0,n_col),intent(in)::t0_num
    real(dp),dimension(n_max_t0,n_col),intent(in)::t0_obs
    real(dp),dimension(n_max_t0,n_col),intent(in)::et0_obs
    
!f2py integer intent(hide),depend(t0_num,t0_obs,et0_obs)::n_max_t0=shape(t0_num,0),n_col=shape(t0_num,1)
    
    tstart=t_start
    tepoch=t_epoch
    tint=t_int
    NB=n_body
    NBDIM=n_body*6
    
    allocate(e_bounds(2,n_body))
    e_bounds(1,:)=zero
    e_bounds(2,:)=one-TOLERANCE
    
    call set_ephem(n_body,n_t0,t0_num,t0_obs,et0_obs)
    
    rvcheck=1
    durcheck=0
    amin=TOLERANCE
    amax=1.e4_dp
    
    return
  end subroutine
  
  !!! SUBROUTINE TO RUN TRADES INTEGRATION AND RETURN RV_SIM AND T0_SIM
  subroutine kelements_to_data(t_start,t_epoch,step_in,t_int,&
    &m_msun,R_rsun,P_day,ecc,argp_deg,mA_deg,inc_deg,lN_deg,&
    &t_rv,transit_flag,n_t0,t0_num,& ! input
    &rv_sim,t0_sim,& ! output
    &n_body,n_rv,n_max_t0) ! dimensions, try to not provide it...

    ! INPUT
    ! t_start      == start of the integration
    ! t_epoch      == reference time epoch
    ! step_in      == initial step size of the integration
    ! t_int        == total integration time in days
    
    ! m_msun       == masses of all the bodies in Msun m_sun(n_body)
    ! R_rsun       == radii of all the bodies in Rsun r_rsun(n_body)
    ! P_day        == periods of all the bodies in days p_day(n_body); p_day(0) = 0
    ! ecc          == eccentricities of all the bodies ecc(n_body); ecc(0) = 0
    ! argp_deg     == argument of pericentre of all the bodies argp_deg(n_body); argp_deg(0) = 0
    ! mA_deg       == mean anomaly of all the bodies mA_deg(n_body); mA_deg(0) = 0
    ! inc_deg      == inclination of all the bodies inc_deg(n_body); inc_deg(0) = 0
    ! lN_deg       == longitude of node of all the bodies lN_deg(n_body); lN_deg(0) = 0

    ! t_rv         == time of the RV datapoints t_rv(n_rv)
    ! transit_flag == logical/boolean vector with which bodies should transit (.true.) or not (.false) transit_flag(n_body); transit_flag(0) = False
    ! n_t0         == number of transits per each body n_t0(n_body); n_t0(0) = 0
    ! t0_num       == epochs/transit number for each body t0_num(n_max_t0,n_body); t0_num(:,0) = 0
    
    ! OUTPUT
    ! rv_sim       == rv simulated in m/s, same dimension of t_rv
    ! t0_sim       == t0 simulated in days, same dimension of t0_num
    
    ! DIMENSIONS
    ! n_body       == number of bodies (take into account the star)
    ! n_rv         == number of radial velocities datapoints
    ! n_max_t0     == maxval(n_t0) == maxval of transits available
    integer::n_body,n_rv,n_max_t0
    
    real(dp),intent(in)::t_start,t_epoch,step_in,t_int
    real(dp),dimension(n_body),intent(in)::m_msun,R_rsun,P_day
    real(dp),dimension(n_body),intent(in)::ecc,argp_deg,mA_deg,inc_deg,lN_deg
    real(dp),dimension(n_RV),intent(in)::t_rv
    logical,dimension(n_body),intent(in)::transit_flag
    integer,dimension(n_body),intent(in)::n_t0
    integer,dimension(n_max_t0,n_body),intent(in)::t0_num
    
    real(dp),dimension(n_RV),intent(out)::rv_sim
    real(dp),dimension(n_max_t0,n_body),intent(out)::t0_sim
    

!f2py    integer,intent(hide),depend(t_rv)::n_rv=len(t_rv)
!f2py    integer,intent(hide),depend(t0_num)::n_max_t0=shape(t0_num,0), n_body=shape(t0_num,1)

! !f2py    integer,intent(hide),depend(n_t0)::n_body=len(m_msun)
    
    integer::id_transit_body=1 ! needed to be == 1
    real(dp),dimension(:),allocatable::rv_temp
    real(dp),dimension(:,:),allocatable::t0_temp
    
    call orbits_to_data(t_start,t_epoch,step_in,t_int,&
      &m_msun,R_rsun,P_day,ecc,argp_deg,mA_deg,inc_deg,lN_deg,&
      &t_rv,RV_temp,&
      &id_transit_body,transit_flag,durcheck,n_t0,t0_num,t0_temp)
    
    rv_sim=rv_temp
    t0_sim=t0_temp
    if(allocated(rv_temp)) deallocate(rv_temp)
    if(allocated(t0_temp)) deallocate(t0_temp)
  
    return
  end subroutine kelements_to_data

  
end module pytrades
