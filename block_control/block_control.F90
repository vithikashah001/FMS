!***********************************************************************
!*                   GNU Lesser General Public License
!*
!* This file is part of the GFDL Flexible Modeling System (FMS).
!*
!* FMS is free software: you can redistribute it and/or modify it under
!* the terms of the GNU Lesser General Public License as published by
!* the Free Software Foundation, either version 3 of the License, or (at
!* your option) any later version.
!*
!* FMS is distributed in the hope that it will be useful, but WITHOUT
!* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
!* FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
!* for more details.
!*
!* You should have received a copy of the GNU Lesser General Public
!* License along with FMS.  If not, see <http://www.gnu.org/licenses/>.
!***********************************************************************
!> @defgroup block_control_mod block_control_mod
!> @ingroup block_control
!> @brief Routines for "blocks" used for  OpenMP threading of column-based
!!        calculations

module block_control_mod

use mpp_mod,         only: mpp_error, NOTE, WARNING, FATAL, mpp_sum, mpp_npes
use mpp_domains_mod, only: mpp_compute_extent
use fms_string_utils_mod, only: string
implicit none

public block_control_type

!> Type to dereference packed index from global index.
!> @ingroup block_control_mod
type :: ix_type
  integer, dimension(:,:), allocatable :: ix
end type ix_type

!> Type to dereference packed index from global indices.
!> @ingroup block_control_mod
type :: pk_type
  integer, dimension(:), allocatable :: ii
  integer, dimension(:), allocatable :: jj
end type pk_type

!> @brief Block data and extents for OpenMP threading of column-based calculations
!> @ingroup block_control_mod
type :: block_control_type
  integer :: nx_block, ny_block  !< blocking factor using mpp-style decomposition
  integer :: nblks               !< number of blocks cover MPI domain
  integer :: isc, iec, jsc, jec  !< MPI domain global extents
  integer :: npz                 !< vertical extent
  integer, dimension(:),        allocatable :: ibs  , &  !< block extents for mpp-style
                                               ibe  , &  !! decompositions
                                               jbs  , &
                                               jbe
  type(ix_type), dimension(:),  allocatable :: ix    !< dereference packed index from global index
  !--- packed blocking fields
  integer, dimension(:),        allocatable :: blksz !< number of points in each individual block
                                                            !! blocks are not required to be uniforom in size
  integer, dimension(:,:),      allocatable :: blkno !< dereference block number using global indices
  integer, dimension(:,:),      allocatable :: ixp   !< dereference packed index from global indices
                                                            !! must be used in conjuction with blkno
  type(pk_type), dimension(:),  allocatable :: index !< dereference global indices from
                                                            !! block/ixp combo
end type block_control_type

!> @addtogroup block_control_mod
!> @{

public :: define_blocks, define_blocks_packed

contains

!###############################################################################
!> @brief Sets up "blocks" used for OpenMP threading of column-based
!!        calculations using rad_n[x/y]xblock from coupler_nml
!!
  subroutine define_blocks (component, Block, isc, iec, jsc, jec, kpts, &
                            nx_block, ny_block, message)
    character(len=*),         intent(in)    :: component !< Component name string
    type(block_control_type), intent(inout) :: Block !< Returns instantiated @ref block_control_type
    integer,                  intent(in)    :: isc, iec, jsc, jec, kpts
    integer,                  intent(in)    :: nx_block, ny_block
    logical,                  intent(inout) :: message !< flag for outputting debug message

!-------------------------------------------------------------------------------
! Local variables:
!       blocks
!       i1
!       i2
!       j1
!       j2
!       text
!       i
!       j
!       nblks
!       ix
!       ii
!       jj
!-------------------------------------------------------------------------------

    integer :: blocks
    integer, dimension(nx_block) :: i1, i2
    integer, dimension(ny_block) :: j1, j2
    character(len=256) :: text
    integer :: i, j, nblks, ix, ii, jj
    integer :: non_uniform_blocks !< Number of non uniform blocks

    if (message) then
      non_uniform_blocks = 0
      if ((mod(iec-isc+1,nx_block) .ne. 0) .or. (mod(jec-jsc+1,ny_block) .ne. 0)) then
        non_uniform_blocks = 1
      endif
      call mpp_sum(non_uniform_blocks)
      if (non_uniform_blocks > 0 ) then
        call mpp_error(NOTE, string(non_uniform_blocks)//" out of "//string(mpp_npes())//" total domains "//&
                       "have non-uniform blocks for block size ("//string(nx_block)//","//string(ny_block)//")")
        message = .false.
      endif
    endif

!--- set up blocks
    if (iec-isc+1 .lt. nx_block) &
        call mpp_error(FATAL, 'block_control: number of '//trim(component)//' nxblocks .gt. &
                             &number of elements in MPI-domain size')
    if (jec-jsc+1 .lt. ny_block) &
        call mpp_error(FATAL, 'block_control: number of '//trim(component)//' nyblocks .gt. &
                             &number of elements in MPI-domain size')
    call mpp_compute_extent(isc,iec,nx_block,i1,i2)
    call mpp_compute_extent(jsc,jec,ny_block,j1,j2)

    nblks = nx_block*ny_block
    Block%isc = isc
    Block%iec = iec
    Block%jsc = jsc
    Block%jec = jec
    Block%npz = kpts
    Block%nx_block = nx_block
    Block%ny_block = ny_block
    Block%nblks = nblks

    if (.not.allocated(Block%ibs)) &
         allocate (Block%ibs(nblks), &
                   Block%ibe(nblks), &
                   Block%jbs(nblks), &
                   Block%jbe(nblks), &
                   Block%ix(nblks) )

    blocks=0
    do j = 1, ny_block
      do i = 1, nx_block
        blocks = blocks + 1
        Block%ibs(blocks) = i1(i)
        Block%jbs(blocks) = j1(j)
        Block%ibe(blocks) = i2(i)
        Block%jbe(blocks) = j2(j)
        allocate(Block%ix(blocks)%ix(i1(i):i2(i),j1(j):j2(j)) )
        ix = 0
        do jj = j1(j), j2(j)
          do ii = i1(i), i2(i)
            ix = ix+1
            Block%ix(blocks)%ix(ii,jj) = ix
          enddo
        enddo
      enddo
    enddo

  end subroutine define_blocks



!###############################################################################
!> @brief Creates and populates a data type which is used for defining the
!!        sub-blocks of the MPI-domain to enhance OpenMP and memory performance.
!!        Uses a packed concept.
!!
  subroutine define_blocks_packed (component, Block, isc, iec, jsc, jec, &
                                   kpts, blksz, message)
    character(len=*),         intent(in)    :: component !< Component name string
    type(block_control_type), intent(inout) :: Block !< Returns instantiated @ref block_control_type
    integer,                  intent(in)    :: isc, iec, jsc, jec, kpts
    integer,                  intent(inout) :: blksz !< block size
    logical,                  intent(inout) :: message !< flag for outputting debug message

!-------------------------------------------------------------------------------
! Local variables:
!       nblks
!       lblksz
!       tot_pts
!       nb
!       ix
!       ii
!       jj
!       text
!-------------------------------------------------------------------------------

    integer :: nblks, lblksz, tot_pts, nb, ix, ii, jj
    character(len=256) :: text

    tot_pts = (iec - isc + 1) * (jec - jsc + 1)
    if (blksz < 0) then
      nblks = 1
      blksz = tot_pts
    else
      nblks = tot_pts/blksz
      if (mod(tot_pts,blksz) .gt. 0) then
        nblks = nblks + 1
      endif
    endif

    if (message) then
      if (mod(tot_pts,blksz) .ne. 0) then
        write( text,'(a,a,2i4,a,i4,a,i4)' ) trim(component),'define_blocks_packed: domain (',&
             (iec-isc+1), (jec-jsc+1),') is not an even divisor with definition (',&
             blksz,') - blocks will not be uniform with a remainder of ',mod(tot_pts,blksz)
        call mpp_error (WARNING, trim(text))
      endif
      message = .false.
    endif

    Block%isc   = isc
    Block%iec   = iec
    Block%jsc   = jsc
    Block%jec   = jec
    Block%npz   = kpts
    Block%nblks = nblks
    if (.not. allocated(Block%blksz)) &
      allocate (Block%blksz(nblks), &
                Block%index(nblks), &
                Block%blkno(isc:iec,jsc:jec), &
                Block%ixp(isc:iec,jsc:jec))

!--- set up blocks
    do nb = 1, nblks
      lblksz = blksz
      if (nb .EQ. nblks) lblksz = tot_pts - (nb-1) * blksz
      Block%blksz(nb) = lblksz
      allocate (Block%index(nb)%ii(lblksz), &
                Block%index(nb)%jj(lblksz))
    enddo

!--- set up packed indices
    nb = 1
    ix = 0
    do jj = jsc, jec
      do ii = isc, iec
        ix = ix + 1
        if (ix .GT. blksz) then
          ix = 1
          nb = nb + 1
        endif
        Block%ixp(ii,jj) = ix
        Block%blkno(ii,jj) = nb
        Block%index(nb)%ii(ix) = ii
        Block%index(nb)%jj(ix) = jj
      enddo
    enddo

  end subroutine define_blocks_packed

end module block_control_mod
!> @}
! close documentation grouping
