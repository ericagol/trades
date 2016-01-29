module PolyChord_driver
  use constants
  use parameters
  use ode_run,only:ode_lm
  implicit none
  
  contains

! read settings in init_trades.f90

! fix the system_parameters in case a parameter has been read with a value not in [par_min, par_max]

  subroutine fix_system_parameters()
    integer::i
    
    do i=1,npar
      if( tofit(i).eq. 1)then
        if( (system_parameters(i).lt.par_min(i)) .or. (system_parameters(i).gt.par_max(i)) )then
          system_parameters(i) = par_min(i)
        end if
      end if
    end do
  
    return
  end subroutine fix_system_parameters

  function loglikelihood(theta,phi)
    use constants,only:dp,zero
    real(dp),intent(in),dimension(:)::theta
    real(dp),intent(out),dimension(:)::phi
    real(dp)::loglikelihood

    real(dp),dimension(:),allocatable::resw
    integer::iflag=1
    
!     write(*,'(a)')"# ================================================ # "
!     write(*,'(a,1000(f17.8))')" phys par = ",theta
    allocate(resw(ndata))
    resw=zero
    call ode_lm(system_parameters,ndata,nfit,theta,resw,iflag)
!     loglikelihood=-0.5_dp*(sum(resw*resw)/real(dof,dp))
    loglikelihood=-0.5_dp*sum(resw*resw) ! resw t.c. sum(resw^2) = fitness = Chi2r*K_chi2r + Chi2wr*K_chi2wr
    deallocate(resw)
!     write(*,'(2(a,f17.8))')" logLikelihood = ",loglikelihood,&
!       &" Chi^2_r = ",-2._dp*loglikelihood
!     write(*,'(a)')"# ================================================ # "
    
    ! Use up these parameters to stop irritating warnings
    if(size(phi).gt.0)phi=zero
  
  end function loglikelihood


  subroutine PC_driver(output_info) ! BASED ON PolyChord.F90 in original PolyChordv1.2 src
    use ini_module,               only: read_params,initialise_program
    use params_module,            only: add_parameter,param_type
    use priors_module
    use settings_module,          only: program_settings,initialise_settings
    use random_module,            only: initialise_random
    use nested_sampling_module,   only: NestedSampling
    use utils_module,             only: STR_LENGTH
    use abort_module,             only: halt_program
#ifdef MPI
    use mpi_module,               only: initialise_mpi, finalise_mpi
    use mpi,                      only: MPI_COMM_WORLD
#endif


    ! Output of the program
    ! 1) mean(log(evidence))
    ! 2) var(log(evidence))
    ! 3) ndead
    ! 4) number of likelihood calls
    ! 5) log(evidence) + log(prior volume)
    double precision, dimension(5)            :: output_info

!     type(program_settings)                    :: settings  ! The program settings  ! in parameters module
    type(prior), dimension(:),allocatable     :: priors    ! The details of the priors

    type(param_type),dimension(:),allocatable :: params         ! Parameter array
    type(param_type),dimension(:),allocatable :: derived_params ! Derived parameter array

    integer::i
    
!     interface
!       subroutine fix_system_parameters()
!       end subroutine
!     end interface

    ! ======= (1) Initialisation =======
    ! We need to initialise:
    ! a) mpi threads
    ! b) random number generator
    ! c) priors & settings
    ! d) loglikelihood

    ! ------- (1a) Initialise MPI threads -------------------
#ifdef MPI
    call initialise_mpi
#endif

    ! ------- (1b) Initialise random number generator -------
    ! Initialise the random number generator with the system time
    ! (Provide an argument to this if you want to set a specific seed
    ! leave argumentless if you want to use the system time)
    call initialise_random()

    
! ------- (1c) Define the parameters of the loglikelihood and the system settings -------
    ! Here we initialise the array params with all of the details we need
    allocate(params(0),derived_params(0))
    ! The argument to add_parameter are:
    ! 1) params:            the parameter array to add to
    ! 2) name:              paramname for getdist processing
    ! 3) latex:             latex name for getdist processing
    ! 4) speed:             The speed of this parameter (lower => slower)
    ! 5) prior_type:        what kind of prior it is
    ! 6) prior_block:       what other parameters are associated with it
    ! 7) prior_parameters:  parameters of the prior
    !                  array   name     latex     speed  prior_type   prior_block prior_parameters
    do i=1,nfit
      call add_parameter(params,parid(i),parid(i),1,uniform_type,1,[minpar(i), maxpar(i)])
    end do

    ! Initialise the program
    call initialise_program(settings,priors,params,derived_params)

    ! ------- (1d) Define the parameters of the loglikelihood and the system settings -------
    ! already set loglikelihood and system settings when reading PolyChord.opt file
    call fix_system_parameters()
    
    
    output_info=zero ! set to zero....why not...
    ! ======= (2) Perform Nested Sampling =======
    ! Call the nested sampling algorithm on our chosen likelihood and priors
#ifdef MPI
    output_info = NestedSampling(loglikelihood,priors,settings,MPI_COMM_WORLD) 
#else
    output_info = NestedSampling(loglikelihood,priors,settings,0) 
#endif


    ! ======= (3) De-initialise =======

    ! Finish off all of the threads
#ifdef MPI
    call finalise_mpi
#endif

    return
  end subroutine
  
end module PolyChord_driver
