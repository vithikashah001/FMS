#***********************************************************************
#*                   GNU Lesser General Public License
#*
#* This file is part of the GFDL Flexible Modeling System (FMS).
#*
#* FMS is free software: you can redistribute it and/or modify it under
#* the terms of the GNU Lesser General Public License as published by
#* the Free Software Foundation, either version 3 of the License, or (at
#* your option) any later version.
#*
#* FMS is distributed in the hope that it will be useful, but WITHOUT
#* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
#* FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
#* for more details.
#*
#* You should have received a copy of the GNU Lesser General Public
#* License along with FMS.  If not, see <http://www.gnu.org/licenses/>.
#***********************************************************************

# This is an automake file for the test_fms/time_manager directory of the FMS
# package.


# Find the fms_mod.mod file.
AM_CPPFLAGS = -I$(top_srcdir)/include -I$(MODDIR)

# Link to the FMS library.
LDADD = $(top_builddir)/libFMS/libFMS.la

# Build this test program.
check_PROGRAMS = test_column_diagnostics_r4 test_column_diagnostics_r8

# This is the source code for the test.
test_column_diagnostics_r4_SOURCES = test_column_diagnostics.F90
test_column_diagnostics_r8_SOURCES = test_column_diagnostics.F90

test_column_diagnostics_r4_CPPFLAGS=$(AM_CPPFLAGS) -DTEST_CD_KIND_=4
test_column_diagnostics_r8_CPPFLAGS=$(AM_CPPFLAGS) -DTEST_CD_KIND_=8

TEST_EXTENSIONS = .sh
SH_LOG_DRIVER = env AM_TAP_AWK='$(AWK)' $(SHELL) $(abs_top_srcdir)/test_fms/tap-driver.sh

# Run the test program.
TESTS = test_column_diagnostics.sh

# These files will be included in the distribution.
EXTRA_DIST = test_column_diagnostics.sh

# Clean up
CLEANFILES = *.nml *.out* *.dpi *.spi *.dyn *.spl fort.*
