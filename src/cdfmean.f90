PROGRAM cdfmean
  !!======================================================================
  !!                     ***  PROGRAM  cdfmean  ***
  !!=====================================================================
  !!  ** Purpose : Compute the Mean Value over the ocean or part of the
  !!               ocean (spatial mean).
  !!
  !!  ** Method  : mean= sum( V * e1 *e2 * e3 *mask )/ sum( e1 * e2 * e3 *mask ))
  !!               Partial cell version
  !!
  !! History : 2.1  : 10/2005  : J.M. Molines : Original code
  !!         : 2.1  : 07/2009  : R. Dussin    : Netcdf output
  !!           3.0  : 01/2011  : J.M. Molines : Doctor norm + Lic.
  !!         : 4.0  : 03/2017  : J.M. Molines  
  !!----------------------------------------------------------------------
  USE cdfio
  USE modcdfnames
  !!----------------------------------------------------------------------
  !! CDFTOOLS_4.0 , MEOM 2017 
  !! $Id$
  !! Copyright (c) 2017, J.-M. Molines 
  !! Software governed by the CeCILL licence (Licence/CDFTOOLSCeCILL.txt)
  !! @class integration
  !!----------------------------------------------------------------------
  IMPLICIT NONE

  INTEGER(KIND=4)                            :: jk, jt, jvar       ! dummy loop index
  INTEGER(KIND=4)                            :: it                 ! time index for vvl
  INTEGER(KIND=4)                            :: ik, ivar     !
  INTEGER(KIND=4)                            :: iimin=0, iimax=0   ! domain limitation for computation
  INTEGER(KIND=4)                            :: ijmin=0, ijmax=0   ! domain limitation for computation
  INTEGER(KIND=4)                            :: ikmin=0, ikmax=0   ! domain limitation for computation
  INTEGER(KIND=4)                            :: narg, iargc, ijarg ! command line 
  INTEGER(KIND=4)                            :: npiglo, npjglo     ! size of the domain
  INTEGER(KIND=4)                            :: npiglo_fi          ! size of the domain from input file
  INTEGER(KIND=4)                            :: npjglo_fi          ! size of the domain from input file
  INTEGER(KIND=4)                            :: npk_fi             ! size of the domain from input file
  INTEGER(KIND=4)                            :: npk, npt           ! size of the domain
  INTEGER(KIND=4)                            :: nvpk               ! vertical levels in working variable
  INTEGER(KIND=4)                            :: numout=10          ! logical unit for mean output file
  INTEGER(KIND=4)                            :: numvar=11          ! logical unit for variance output file
  INTEGER(KIND=4)                            :: ikx=1, iky=1       ! dims of netcdf output file
  INTEGER(KIND=4)                            :: nvars              ! number of values to write in cdf output
  INTEGER(KIND=4)                            :: ncout, ierr        ! for netcdf output
  INTEGER(KIND=4)                            :: idep, idep_max     ! possible depth index, maximum
  INTEGER(KIND=4)                            :: n_sum,n_sum3d      ! index of sum, sum3d in id_varout
  INTEGER(KIND=4)                            :: n_mean,n_mean3d    ! index of mean, mean3d in id_varout
  INTEGER(KIND=4)                            :: n_var,n_var3d      ! index of var, var3d in id_varout

  INTEGER(KIND=4), DIMENSION(:), ALLOCATABLE :: ipk, id_varout

  REAL(KIND=4)                               :: zspval             ! missing value
  REAL(KIND=4), DIMENSION(1,1)               :: rdummy             ! dummy variable
  REAL(KIND=4), DIMENSION(:,:),  ALLOCATABLE :: e1, e2, e3, zv     ! metrics, velocity
  REAL(KIND=4), DIMENSION(:,:),  ALLOCATABLE :: zmask              ! npiglo x npjglo
  REAL(KIND=4), DIMENSION(:,:),  ALLOCATABLE :: rdumlon, rdumlat   ! dummy lon/lat for output file
  REAL(KIND=4), DIMENSION(:,:),  ALLOCATABLE :: rdummymean         ! array for mean value on output file
  REAL(KIND=4), DIMENSION(:),    ALLOCATABLE :: gdep               ! depth 
  REAL(KIND=4), DIMENSION(:),    ALLOCATABLE :: zdep               ! depth of the whole vertical levels
  REAL(KIND=4), DIMENSION(:),    ALLOCATABLE :: e31d               ! 1d vertical spacing
  REAL(KIND=4), DIMENSION(:),    ALLOCATABLE :: tim                ! time counter

  REAL(KIND=8)                               :: dvol, dsum, dsurf  ! cumulated values
  REAL(KIND=8)                               :: dvol2d, dsum2d     !
  REAL(KIND=8)                               :: dvar2d, dvar       ! for variance computing
  REAL(KIND=8), DIMENSION(:),    ALLOCATABLE :: dvmeanout          ! spatial mean
  REAL(KIND=8), DIMENSION(:),    ALLOCATABLE :: dvariance           ! spatial variance
  REAL(KIND=8), DIMENSION(:),    ALLOCATABLE :: dvmeanout3d         ! global 3D mean value
  REAL(KIND=8), DIMENSION(:),    ALLOCATABLE :: dvariance3d         ! global 3D mean variance

  CHARACTER(LEN=256)                         :: cv_nam             ! current variable name
  CHARACTER(LEN=256)                         :: cv_dep             ! deptht name
  CHARACTER(LEN=20)                          :: cv_e1, cv_e2       ! horizontal metrics names
  CHARACTER(LEN=20)                          :: cv_e3, cv_e31d     ! vertical metrics names
  CHARACTER(LEN=20)                          :: cv_msk = ''        ! mask variable name
  CHARACTER(LEN=256)                         :: cf_e3              ! name of the file holding vertical metrics
  CHARACTER(LEN=256)                         :: cf_in              ! input file name
  CHARACTER(LEN=256)                         :: cf_out   = 'cdfmean.txt' ! ASCII output file for mean
  CHARACTER(LEN=256)                         :: cf_var   = 'cdfvar.txt'  ! ASCII output file for variance
  CHARACTER(LEN=256)                         :: cf_ncout = 'cdfmean.nc'  ! NCDF output file
  CHARACTER(LEN=256)                         :: cf_zerom = 'zeromean.nc' ! NCDF output file with zeromean field
  CHARACTER(LEN=256)                         :: ctype              ! type of C-grid point to work with
  CHARACTER(LEN=256)                         :: clunits            ! attribute of output file : units
  CHARACTER(LEN=256)                         :: cllong_name        !     "      long name
  CHARACTER(LEN=256)                         :: clshort_name       !     "      short name
  CHARACTER(LEN=256)                         :: cglobal            !     "      global 
  CHARACTER(LEN=256)                         :: cldum              ! dummy char variable
  CHARACTER(LEN=256), DIMENSION(:), ALLOCATABLE :: clv_dep         ! array of possible depth name (or 3rd dimension)
  CHARACTER(LEN=256), DIMENSION(:), ALLOCATABLE :: cv_names        ! list of file names

  TYPE(variable), DIMENSION(:),  ALLOCATABLE :: stypvar            ! structure of output
  TYPE(variable), DIMENSION(:),  ALLOCATABLE :: stypvarin          ! structure of input data
  TYPE(variable), DIMENSION(:),  ALLOCATABLE :: stypvarzero        ! structure of zeromean output

  LOGICAL                                    :: lfull     = .FALSE.! full step  flag
  LOGICAL                                    :: lvar      = .FALSE.! variance  flag
  LOGICAL                                    :: lsum      = .FALSE.! sum  flag
  LOGICAL                                    :: lzeromean = .FALSE.! zero mean  flag
  LOGICAL                                    :: lnodep    = .FALSE.! no depth flag
  LOGICAL                                    :: lchk               ! flag for missing files
  !!----------------------------------------------------------------------
  CALL ReadCdfNames()

  narg = iargc()
  IF ( narg == 0 ) THEN
     PRINT *,' usage : cdfmean -f IN-file -v IN-var -p C-point  ...'
     PRINT *,'       ... [-w imin imax jmin jmax kmin kmax] [-full] [-var] [-zeromean]...'
     PRINT *,'       ... [-M MSK-file VAR-mask ] [-o OUT-file] [ -ot OUTASCII-file] ...'
     PRINT *,'       ... [-oz ZEROMEAN-file] [-ov VAR-file] [ -vvl ] [-S]'
     PRINT *,'      '
     PRINT *,'     PURPOSE :'
     PRINT *,'        Compute the mean value of the field (3D, weighted). For 3D fields,'
     PRINT *,'        a horizontal mean for each level is also given. If a spatial window'
     PRINT *,'        is specified, the mean value is computed only in this window.'
     PRINT *,'      '
     PRINT *,'     ARGUMENTS :'
     PRINT *,'       -f IN-file : input netcdf file.'
     PRINT *,'       -v IN-var  : name of netcdf variable to work with.'
     PRINT *,'       -p C-point : one of T|U|V|F|W indicating the position of IN-var on the'
     PRINT *,'                C-grid.' 
     PRINT *,'      '
     PRINT *,'     OPTIONS :'
     PRINT *,'       [-w imin imax jmin jmax kmin kmax] : spatial window where mean value'
     PRINT *,'                is computed:' 
     PRINT *,'                  if imin = 0 then ALL i are taken'
     PRINT *,'                  if jmin = 0 then ALL j are taken'
     PRINT *,'                  if kmin = 0 then ALL k are taken'
     PRINT *,'       [-M MSK-file VAR-mask] : Allow the use of a non standard mask file '
     PRINT *,'              with VAR-mask, instead of ',TRIM(cn_fmsk),' and the variable'
     PRINT *,'              associated with the grid point set by -p argument.'
     PRINT *,'              This option is a usefull alternative to the -w option, when the '
     PRINT *,'              area of interest is not ''box-like''. However, for vertical '
     PRINT *,'              selection, both -w and -M can be used together.'
     PRINT *,'       [-full ] : compute the mean for full steps, instead of default '
     PRINT *,'              partial steps.'
     PRINT *,'       [-var ]: also compute the spatial variance of IN-var.'
     PRINT *,'       [-zeromean ] : create a file with cdfvar having a zero spatial mean.'
     PRINT *,'       [-o OUT-file]: specify the name of the output file instead of ',TRIM(cf_ncout)
     PRINT *,'       [-ot OUTASCII-file] : specify the name of the output ASCII file instead '
     PRINT *,'                   of ',TRIM(cf_out)
     PRINT *,'       [-oz ZEROMEAN-file] : specify the name of the output netcdf file for '
     PRINT *,'                   option -zeromean, instead of ', TRIM(cf_zerom)
     PRINT *,'       [-ov VAR-file] : specify the name of the output text file for option '
     PRINT *,'                   -var, instead of ', TRIM(cf_var)
     PRINT *,'       [-vvl ] : use time-varying vertical metrics.'
     PRINT *,'       [-S ] : save the weighted sum of the fields in addition to the mean '
     PRINT *,'               values. (Replace somehow cdfsum)'
     PRINT *,'      '
     PRINT *,'     REQUIRED FILES :'
     PRINT *,'       Files ', TRIM(cn_fhgr),', ', TRIM(cn_fzgr),', ', TRIM(cn_fmsk)
     PRINT *,'      '
     PRINT *,'     OUTPUT : '
     PRINT *,'       - netcdf file : ', TRIM(cf_ncout)
     PRINT *,'           variables : mean_<IN-var>, mean_3D_<IN-var> '
     PRINT *,'                    [var_<IN-VAR>, var_3D_<IN-var>, in case of -var]'
     PRINT *,'       - netcdf file : ', TRIM(cf_zerom),' [ in case of -zeromean option]'
     PRINT *,'           variables : <IN-var>'
     PRINT *,'       - ASCII files : ', TRIM(cf_out) 
     PRINT *,'                       [ ',TRIM(cf_var),', in case of -var ]'
     PRINT *,'       - all output on ASCII files are also sent to standard output.'
     PRINT *,'      '
     STOP
  ENDIF

  ! Open standard output with recl=256 to avoid wrapping of long lines (ifort)
  OPEN(6,FORM='FORMATTED',RECL=256)  ! ifort
  ! OPEN(6,FORM='FORMATTED')          ! gfortran

  cglobal = 'Partial step computation'
  ijarg = 1 
  DO WHILE ( ijarg <= narg )
     CALL getarg(ijarg, cldum ) ; ijarg = ijarg + 1 
     SELECT CASE (cldum) 
     CASE ('-f'        ) ; CALL getarg(ijarg, cf_in    ) ; ijarg = ijarg + 1
     CASE ('-v'        ) ; CALL getarg(ijarg, cv_nam   ) ; ijarg = ijarg + 1
     CASE ('-p'        ) ; CALL getarg(ijarg, ctype    ) ; ijarg = ijarg + 1
        ! options
     CASE ('-full'     ) ; lfull     = .TRUE.  ; cglobal = 'full step computation'
     CASE ('-var'      ) ; lvar      = .TRUE. 
     CASE ('-zeromean' ) ; lzeromean = .TRUE. 
     CASE ('-vvl'      ) ; lg_vvl    = .TRUE. 
     CASE ('-w'        ) ; CALL getarg(ijarg, cldum    ) ; ijarg = ijarg + 1 ;  READ(cldum,*) iimin
        ;                  CALL getarg(ijarg, cldum    ) ; ijarg = ijarg + 1 ;  READ(cldum,*) iimax
        ;                  CALL getarg(ijarg, cldum    ) ; ijarg = ijarg + 1 ;  READ(cldum,*) ijmin
        ;                  CALL getarg(ijarg, cldum    ) ; ijarg = ijarg + 1 ;  READ(cldum,*) ijmax
        ;                  CALL getarg(ijarg, cldum    ) ; ijarg = ijarg + 1 ;  READ(cldum,*) ikmin
        ;                  CALL getarg(ijarg, cldum    ) ; ijarg = ijarg + 1 ;  READ(cldum,*) ikmax
     CASE ('-o'        ) ; CALL getarg(ijarg, cf_ncout ) ; ijarg = ijarg + 1
     CASE ('-oz'       ) ; CALL getarg(ijarg, cf_zerom ) ; ijarg = ijarg + 1
     CASE ('-ov'       ) ; CALL getarg(ijarg, cf_var   ) ; ijarg = ijarg + 1
     CASE ('-ot'       ) ; CALL getarg(ijarg, cf_out   ) ; ijarg = ijarg + 1
     CASE ('-M'        ) ; CALL getarg ( ijarg, cn_fmsk) ; ijarg = ijarg + 1
        ;                  CALL getarg ( ijarg, cv_msk ) ; ijarg = ijarg + 1
     CASE ('-S'        ) ; lsum = .TRUE.
     CASE DEFAULT        ; PRINT *,' ERROR : ',TRIM(cldum),' : unknown option.' ; STOP
     END SELECT
  END DO

  lchk = chkfile(cn_fhgr)
  lchk = chkfile(cn_fzgr) .OR. lchk
  lchk = chkfile(cn_fmsk) .OR. lchk
  lchk = chkfile(cf_in  ) .OR. lchk
  IF ( lchk ) STOP ! missing file

  cv_dep   = 'none'
  npiglo = getdim (cf_in, cn_x)
  npjglo = getdim (cf_in, cn_y)

  ! looking for npk among various possible name
  idep_max=8
  ALLOCATE ( clv_dep(idep_max) )
  clv_dep(:) = (/cn_z,'z','sigma','nav_lev','levels','ncatice','icbcla','icbsect'/)
  idep=1  ; ierr=1000
  DO WHILE ( ierr /= 0 .AND. idep <= idep_max )
     npk  = getdim (cf_in, clv_dep(idep), cdtrue=cv_dep, kstatus=ierr)
     idep = idep + 1
  ENDDO

  IF ( ierr /= 0 ) THEN  ! none of the dim name was found
     PRINT *,' assume file with no depth'
     npk=0
  ENDIF

  npt   = getdim (cf_in, cn_t)
  nvpk  = getvdim(cf_in, cv_nam)
  ! save original npiglo, npiglo
  npiglo_fi = npiglo
  npjglo_fi = npjglo
  npk_fi    = npk

  IF (npk   == 0 ) THEN ; lnodep = .TRUE.;  npk = 1; npk_fi = 1      ;
  ENDIF ! no depth dimension ==> 1 level
  IF (iimin /= 0 ) THEN ; npiglo = iimax -iimin + 1;  ELSE ; iimin=1 ;
  ENDIF
  IF (ijmin /= 0 ) THEN ; npjglo = ijmax -ijmin + 1;  ELSE ; ijmin=1 ;
  ENDIF
  IF (ikmin /= 0 ) THEN ; npk    = ikmax -ikmin + 1;  ELSE ; ikmin=1 ;
  ENDIF

  IF (nvpk == 2 ) nvpk = 1
  IF (nvpk == 3 ) nvpk = npk

  WRITE(6, *) 'npiglo = ', npiglo
  WRITE(6, *) 'npjglo = ', npjglo
  WRITE(6, *) 'npk    = ', npk
  WRITE(6, *) 'npt    = ', npt
  WRITE(6, *) 'nvpk   = ', nvpk
  WRITE(6, *) 'depth dim name is ', TRIM(cv_dep)

  ! Allocate arrays
  ALLOCATE ( zmask(npiglo,npjglo) )
  ALLOCATE ( zv   (npiglo,npjglo) )
  ALLOCATE ( e1   (npiglo,npjglo), e2(npiglo,npjglo), e3(npiglo,npjglo) )
  ALLOCATE ( gdep (npk), e31d(npk), tim(npt) , dvariance3d(npt), dvmeanout3d(npt) )
  ALLOCATE ( zdep(npk_fi) )

  SELECT CASE (TRIM(ctype))
  CASE ( 'T' )
     cv_e1    = cn_ve1t
     cv_e2    = cn_ve2t
     cf_e3    = cn_fe3t
     cv_e3    = cn_ve3t
     cv_e31d  = cn_ve3t
     IF (cv_msk   == '' ) THEN ; cv_msk = cn_tmask ;
     ENDIF
     cv_dep   = cn_gdept
  CASE ( 'U' )
     cv_e1    = cn_ve1u
     cv_e2    = cn_ve2u
     cf_e3    = cn_fe3u
     cv_e3    = cn_ve3u
     cv_e31d  = cn_ve3t
     IF (cv_msk   == '' ) THEN ; cv_msk = cn_umask ;
     ENDIF
     cv_dep   = cn_gdept
  CASE ( 'V' )
     cv_e1    = cn_ve1v
     cv_e2    = cn_ve2v
     cf_e3    = cn_fe3v
     cv_e3    = cn_ve3v
     cv_e31d  = cn_ve3t
     IF (cv_msk   == '' ) THEN ; cv_msk = cn_vmask ;
     ENDIF
     cv_dep   = cn_gdept
  CASE ( 'F' )   ! JMM : WARNING : e3f metrics is not written any where we take e3t for the time being 111
     cv_e1    = cn_ve1f
     cv_e2    = cn_ve2f
     cf_e3    = cn_fe3t
     cv_e3    = cn_ve3t
     cv_e31d  = cn_ve3t
     IF (cv_msk   == '' ) THEN ; cv_msk = cn_fmask ;
     ENDIF
     cv_dep   = cn_gdept
  CASE ( 'W' )
     cv_e1    = cn_ve1t
     cv_e2    = cn_ve2t
     cf_e3    = cn_fe3t
     cv_e3    = cn_ve3w
     cv_e31d  = cn_ve3w
     IF (cv_msk   == '' ) THEN ; cv_msk = cn_tmask ;
     ENDIF
     cv_dep   = cn_gdepw
  CASE DEFAULT
     PRINT *, 'this type of variable is not known :', TRIM(ctype)
     STOP
  END SELECT

  e1(:,:) = getvar  (cn_fhgr, cv_e1,  1,  npiglo, npjglo, kimin=iimin, kjmin=ijmin)
  e2(:,:) = getvar  (cn_fhgr, cv_e2,  1,  npiglo, npjglo, kimin=iimin, kjmin=ijmin)
  IF ( lfull )  e31d(:) = getvare3(cn_fzgr, cv_e31d, npk)

  zdep(:) = getvare3(cn_fzgr, cv_dep, npk_fi)
  gdep(:) = zdep(ikmin:npk - ikmin + 1)

  IF ( lvar ) THEN ; nvars = 4  ! space for variance too
  ELSE             ; nvars = 2  ! default value
  ENDIF
  IF ( lsum ) THEN ; nvars = nvars + 2  ! add sum and sum3d
  ENDIF

  ALLOCATE ( stypvar(nvars), ipk(nvars), id_varout(nvars) )
  ALLOCATE ( rdumlon(ikx,iky), rdumlat(ikx,iky), rdummymean(ikx,iky) )
  ALLOCATE ( dvmeanout(npk) )
  IF ( lvar ) ALLOCATE ( dvariance(npk) )

  CALL CreateOutput

  OPEN(numout,FILE=cf_out)
  IF ( lvar ) OPEN(numvar,FILE=cf_var)
  IF ( lg_vvl ) cf_e3 = cf_in

  DO jt=1,npt
     IF ( lg_vvl ) THEN ; it = jt
     ELSE               ; it = 1
     ENDIF
     dvol = 0.d0
     dsum = 0.d0
     dvar = 0.d0
     DO jk = 1, nvpk
        ik = jk+ikmin-1
        ! Get velocities v at ik
        zv   (:,:) = getvar(cf_in,   cv_nam, ik, npiglo, npjglo, kimin=iimin, kjmin=ijmin, ktime=jt)
        zmask(:,:) = getvar(cn_fmsk, cv_msk, ik, npiglo, npjglo, kimin=iimin, kjmin=ijmin          )
        IF ( lfull ) THEN
           e3(:,:) = e31d(jk)
        ELSE
           e3(:,:) = getvar(cf_e3, cv_e3, ik, npiglo, npjglo, kimin=iimin, kjmin=ijmin, ktime=it, ldiom=.NOT.lg_vvl )
        ENDIF
        !
        dsurf  = SUM(DBLE(          e1 * e2      * zmask))
        dvol2d = SUM(DBLE(          e1 * e2 * e3 * zmask))
        dvol   = dvol + dvol2d
        dsum2d = SUM(DBLE(zv      * e1 * e2 * e3 * zmask))
        dvar2d = SUM(DBLE(zv * zv * e1 * e2 * e3 * zmask))
        dsum   = dsum + dsum2d
        dvar   = dvar + dvar2d

        IF (dvol2d /= 0 )THEN
           dvmeanout(jk) = dsum2d/dvol2d
           WRITE(6,*)' Mean value at level ',ik,'(',gdep(jk),' m) ',dvmeanout(jk), 'surface = ',dsurf/1.e6,' km^2'
           WRITE(numout,9004) gdep(jk), ik, dvmeanout(jk)
           IF ( lvar ) THEN
              dvariance(jk) = dvar2d/dvol2d - dvmeanout(jk) * dvmeanout(jk)
              WRITE(6,*)' Variance value at level ',ik,'(',gdep(jk),' m) ',dvariance(jk), 'surface = ',dsurf/1.e6,' km^2'
              WRITE(numvar,9004) gdep(jk), ik, dvariance(jk)
           ENDIF
        ELSE
           WRITE(6,*) ' No points in the water at level ',ik,'(',gdep(jk),' m) '
           dvmeanout(jk) = 99999.
           IF( lvar ) dvariance(jk) = 99999.
        ENDIF

        rdummymean(1,1) = dvmeanout(jk)
        ierr            = putvar(ncout, id_varout(n_mean), rdummymean, jk, ikx, iky, ktime=jt )
        IF ( lvar ) THEN
           rdummymean(1,1) = dvariance(jk)
           ierr            = putvar(ncout, id_varout(n_var), rdummymean, jk, ikx, iky, ktime=jt )
        ENDIF
        IF ( lsum ) THEN
           rdummymean(1,1) = dsum2d
           ierr            = putvar(ncout, id_varout(n_sum), rdummymean, jk, ikx, iky, ktime=jt )
        ENDIF
     END DO

     dvmeanout3d(jt) = dsum / dvol
     WRITE(6,*) ' Mean value over the ocean: ', dvmeanout3d(jt), jt
     rdummy(:,:) = dvmeanout3d(jt)
     ierr = putvar0d(ncout, id_varout(n_mean3d), rdummy, ktime=jt )

     IF ( lvar ) THEN
        dvariance3d(jt) = dvar/dvol - dsum / dvol * dsum / dvol
        WRITE(6,*) ' Variance over the ocean: ', dvariance3d(jt), jt
        rdummy(:,:) = dvariance3d(jt)
        ierr = putvar0d(ncout, id_varout(n_var3d), rdummy, ktime=jt )
     ENDIF
     
     IF ( lsum ) THEN
        WRITE(6,*) ' Sum over the ocean: ', dsum, jt
        rdummy(:,:) = dsum
        ierr = putvar0d(ncout, id_varout(n_sum3d), rdummy, ktime=jt )
     ENDIF

  END DO  ! time loop

  CLOSE(numout)
  IF ( lvar ) CLOSE(numvar)

  ierr = closeout(ncout)
9004 FORMAT(f9.2,' ',i2,' ',f9.2)

  ! -zeromean option activated : rest the spatial mean computed above for each timeframe
  !           from the original variable, and output the result to zeromean.nc
  !           This replaces exactly the cdfzeromean tool
  !           The mean value which is used here is eventually computed on a reduced region
  IF ( lzeromean )  THEN
     DEALLOCATE ( zv, zmask, id_varout, ipk )
     npiglo = npiglo_fi ; npjglo = npjglo_fi
     ALLOCATE (zv(npiglo,npjglo), zmask(npiglo,npjglo) )

     ! re-read file and rest mean value from the variable and store on file
     nvars = getnvar(cf_in)
     ALLOCATE ( stypvarin(nvars), cv_names(nvars)    )
     ALLOCATE ( id_varout(1), ipk(1), stypvarzero(1) )

     CALL CreateOutputZeromean

     DO jt=1,npt
        DO jk = 1, nvpk
           ik = jk+ikmin-1
           zv   (:,:) = getvar(cf_in,   cv_nam,   ik, npiglo, npjglo, ktime=jt)
           zmask(:,:) = getvar(cn_fmsk, cv_msk, ik, npiglo, npjglo)

           WHERE (zmask /= 0 ) zv(:,:) = zv(:,:) - dvmeanout3d(jt)
           ierr = putvar(ncout, id_varout(1), zv, ik, npiglo, npjglo, ktime=jt )
        END DO
     END DO
     ierr=closeout(ncout              )
  ENDIF

CONTAINS

  SUBROUTINE CreateOutput
    !!---------------------------------------------------------------------
    !!                  ***  ROUTINE CreateOutput  ***
    !!
    !! ** Purpose :  Create netcdf output file(s) 
    !!
    !! ** Method  :  Use stypvar global description of variables
    !!
    !!----------------------------------------------------------------------
    INTEGER(KIND=4) :: ivar   ! variable counter in id_varout
    !!----------------------------------------------------------------------
    rdumlon(:,:) = 0.
    rdumlat(:,:) = 0.

    ipk(1) = nvpk ! mean for each level
    ipk(2) = 1   ! 3D mean
    IF ( lvar ) THEN
       ipk(3) = nvpk ! variance for each level
       ipk(4) = 1   ! 3D variance
    ENDIF

    ierr=getvaratt (cf_in, cv_nam, clunits, zspval, cllong_name, clshort_name)

    ! define new variables for output 
    stypvar%cunits            = TRIM(clunits)
    stypvar%rmissing_value    = 99999.
    stypvar%valid_min         = -1000.
    stypvar%valid_max         = 1000.
    stypvar%scale_factor      = 1.
    stypvar%add_offset        = 0.
    stypvar%savelog10         = 0.
    stypvar%conline_operation = 'N/A'

    ivar=1 ; n_mean=ivar
    stypvar(n_mean)%cname          = 'mean_'//TRIM(cv_nam)
    stypvar(n_mean)%clong_name     = 'mean_'//TRIM(cllong_name)
    stypvar(n_mean)%cshort_name    = 'mean_'//TRIM(clshort_name)
    stypvar(n_mean)%caxis          = 'ZT'

    ivar=ivar+1 ; n_mean3d=ivar
    stypvar(n_mean3d)%cname          = 'mean_3D'//TRIM(cv_nam)
    stypvar(n_mean3d)%clong_name     = 'mean_3D'//TRIM(cllong_name)
    stypvar(n_mean3d)%cshort_name    = 'mean_3D'//TRIM(clshort_name)
    stypvar(n_mean3d)%caxis          = 'T'

    IF ( lvar) THEN
       ivar=ivar+1 ; n_var=ivar
       stypvar(n_var)%cunits         = TRIM(clunits)//'^2'
       stypvar(n_var)%cname          = 'var_'//TRIM(cv_nam)
       stypvar(n_var)%clong_name     = 'var_'//TRIM(cllong_name)
       stypvar(n_var)%cshort_name    = 'var_'//TRIM(clshort_name)
       stypvar(n_var)%caxis          = 'ZT'

       ivar=ivar+1 ; n_var3d=ivar
       stypvar(n_var3d)%cunits         = TRIM(clunits)//'^2'
       stypvar(n_var3d)%cname          = 'var_3D'//TRIM(cv_nam)
       stypvar(n_var3d)%clong_name     = 'var_3D'//TRIM(cllong_name)
       stypvar(n_var3d)%cshort_name    = 'var_3D'//TRIM(clshort_name)
       stypvar(n_var3d)%caxis          = 'T'
    ENDIF
    IF ( lsum ) THEN
       ivar=ivar+1 ; n_sum=ivar
       stypvar(n_sum)%cunits         = TRIM(clunits)
       stypvar(n_sum)%cname          = 'sum_'//TRIM(cv_nam)
       stypvar(n_sum)%clong_name     = 'sum_'//TRIM(cllong_name)
       stypvar(n_sum)%cshort_name    = 'sum_'//TRIM(clshort_name)
       stypvar(n_sum)%caxis          = 'ZT'

       ivar=ivar+1 ; n_sum3d=ivar
       stypvar(n_sum3d)%cunits         = TRIM(clunits)
       stypvar(n_sum3d)%cname          = 'sum_3D'//TRIM(cv_nam)
       stypvar(n_sum3d)%clong_name     = 'sum_3D'//TRIM(cllong_name)
       stypvar(n_sum3d)%cshort_name    = 'sum_3D'//TRIM(clshort_name)
       stypvar(n_sum3d)%caxis          = 'T'

    ENDIF

    ! create output fileset
    ncout = create      (cf_ncout,   'none',  ikx,   iky,   nvpk, cdep=cv_dep)
    ierr  = createvar   (ncout,      stypvar, nvars, ipk,   id_varout, cdglobal=TRIM(cglobal) )
    ierr  = putheadervar(ncout,      cf_in,  ikx, iky, npk, pnavlon=rdumlon, pnavlat=rdumlat, pdep=gdep(1:nvpk), cdep=cv_dep)
    tim   = getvar1d(cf_in, cn_vtimec, npt)
    ierr  = putvar1d(ncout,  tim,       npt, 'T')


  END SUBROUTINE CreateOutput

  SUBROUTINE CreateOutputZeromean
    !!---------------------------------------------------------------------
    !!                  ***  ROUTINE CreateOutputZeromean  ***
    !!
    !! ** Purpose :  Create netcdf output file(s) for zeromean option
    !!
    !! ** Method  :  Use stypvar global description of variables
    !!
    !!----------------------------------------------------------------------
    cv_names(:) = getvarname(cf_in, nvars, stypvarin)

    ! look for the working variable
    DO jvar = 1, nvars
       IF ( TRIM(cv_names(jvar)) == TRIM(cv_nam) ) EXIT
    END DO
    ivar = jvar

    ipk(1)                        = nvpk
    stypvarzero(1)%cname          = cv_nam
    stypvarzero%cunits            = stypvarin(ivar)%cunits
    stypvarzero%rmissing_value    = stypvarin(ivar)%rmissing_value
    stypvarzero%valid_min         = stypvarin(ivar)%valid_min - MAXVAL(dvmeanout3d)
    stypvarzero%valid_max         = stypvarin(ivar)%valid_max - MINVAL(dvmeanout3d)
    stypvarzero(1)%clong_name     = stypvarin(ivar)%clong_name//' zero mean '
    stypvarzero(1)%cshort_name    = cv_nam
    stypvarzero%conline_operation = 'N/A'
    stypvarzero%caxis             = stypvarin(ivar)%caxis

    ik=nvpk
    IF ( lnodep ) ik = 0  ! no depth variable in input file : the same in output file
    ncout = create      (cf_zerom, cf_in,        npiglo, npjglo, ik            )
    ierr  = createvar   (ncout ,   stypvarzero , 1,      ipk,    id_varout     )
    ierr  = putheadervar(ncout,    cf_in,        npiglo, npjglo, ik , pdep=zdep)
    tim   = getvar1d(cf_in, cn_vtimec, npt)
    ierr=putvar1d(ncout, tim, npt,'T')

  END SUBROUTINE CreateOutputZeromean

END PROGRAM cdfmean
