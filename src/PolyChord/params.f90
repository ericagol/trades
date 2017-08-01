module params_module
  use constants,only:dp
  use utils_module, only: STR_LENGTH
    implicit none

    type param_type
        character(len=STR_LENGTH) :: paramname   ! Name of parameter
        character(len=STR_LENGTH) :: latex       ! LaTeX name
        integer                   :: speed       ! grade of parameter
        integer                   :: prior_type  ! type of prior
        integer                   :: prior_block ! prior block

        ! Parameters in the prior
        real(dp), dimension(:), allocatable :: prior_params
    end type param_type

    contains

    subroutine assign_parameter(param,paramname,latex,speed,prior_type,prior_block,prior_params)
        implicit none
        character(len=*),intent(in) :: paramname   ! Name of parameter
        character(len=*),intent(in) :: latex       ! LaTeX name
        integer         ,intent(in) :: speed       ! grade of parameter
        integer         ,intent(in) :: prior_type  ! type of prior
        integer         ,intent(in) :: prior_block ! prior block
        type(param_type),intent(out):: param       ! Parameter to be returned

        ! Parameters in the prior
        real(dp), dimension(:),intent(in) :: prior_params


        write(param%paramname,'(A)') paramname
        write(param%latex,'(A)') latex
        param%speed = speed
        param%prior_type = prior_type
        param%prior_block = prior_block
        allocate( param%prior_params(size(prior_params)) )
        param%prior_params = prior_params

    end subroutine assign_parameter

    subroutine add_parameter(params,paramname,latex,speed,prior_type,prior_block,prior_params)
        implicit none
        ! Parameter array
        type(param_type),dimension(:),allocatable,intent(inout) :: params

        character(len=*),intent(in) :: paramname   ! Name of parameter
        character(len=*),intent(in) :: latex       ! LaTeX name
        integer         ,intent(in),optional :: speed       ! grade of parameter
        integer         ,intent(in),optional :: prior_type  ! type of prior
        integer         ,intent(in),optional :: prior_block ! prior block

        ! Parameters in the prior
        real(dp), dimension(:),intent(in),optional :: prior_params 
        real(dp), dimension(0) :: blank_params 

        ! expand parameter array
        type(param_type), dimension(:),allocatable :: temp_params

        integer :: num_params 


        num_params = size(params)

        allocate(temp_params(num_params))
        temp_params = params

        deallocate(params)
        allocate(params(num_params+1))

        params(1:num_params) = temp_params


        if(present(speed) .and. present(prior_type) .and. present(prior_block) .and. present(prior_params) ) then
            call assign_parameter(params(num_params+1),paramname,latex,speed,prior_type,prior_block,prior_params) 
        else
            call assign_parameter(params(num_params+1),paramname,latex,1,0,0,blank_params) 
        end if

    end subroutine add_parameter


end module params_module
