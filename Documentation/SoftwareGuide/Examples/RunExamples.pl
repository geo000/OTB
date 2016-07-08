#!/usr/bin/env perl

#
#
# This Script is used to infer figure dependencies from the .cxx/.txx source
# files in the Insight/Examples directory.
# 
# This automatic generation mechanism guaranties that the figures 
# presented on the SoftwareGuide book match exactly the code
# the is compiled and updated in the source repository.
#
# To automate generation, the example source files must contain tags such as
#   .
#   .
# //  Software Guide : BeginCommandLineArgs
# //    INPUTS: {BrainProtonDensitySlice.png}, {BrainProtonDensitySliceR13X13Y17.png}
# //    INPUTS: {SomeOtherInputfile.png}, {MoreInputfiles.png}
# //    OUTPUTS: {GradientDiffusedOutput.png}, {Output2.txt}
# //    5 0.25 3
# //  Software Guide : EndCommandLineArgs
#  .
# If you are including figures, but they are not specified on the command line,
# but are nevertheless generated by the source, you may specify enclose them
# in [] instead.
#
# Multiple tags may be specified.
# 
# Please do not specify paths along with the file names. A list of search paths 
# where input data files may be found is specified through CMAKE. Paths are 
# specified in a colon seperated list such as
#     /Insight/Examples/Data:/VTK/VTKData
# Specifying the root path will suffice. A recursive search for input data 
# is done.
#
# The output of this script is a set of "ExampleSourceFileName.cmake" file. THe
# file contains a set of macros used by CMake to infer figure dependencies, 
# possibly across source files. ie. One example may be used to generate a 
# figure used as input to another example.
# 
# Dependencies for a figure are only inferred if the figure is included 
# in the software guide with the \includegraphics tag.
# 
# Generated figures are stored in Art/Generated.
# 
# The script is invoked from CMAKE if BUILD FIGURES is ON
#
# If BUILD FIGURES is OFF, it is expected that the images be present in either
# (.png, .fig, .jpg, .eps) format in the Art/ folder
#
# Resolving the flipping images issue:
# CMakeLists contains a list of the input files whose eps files need to be flipped
# when included in the SW guide. Their corresponding output eps files will be flipped as
# well during inclusion in the SW guide
# Note that the eps files are flipped, not the inputs or the outputs themselves. The
# files that are used in the command line arguments etc are the original ones. In other 
# words every image that you see in the SW guide that is the same as or is generated
# from the list of images in teh CMakeLists file is a flipped version!
# 
use File::Spec; #for platform independent file paths
use File::Find; #for platform independent recursive search of input images in 
                #specified directories
use File::Copy;
use IO::File;

#
# Tag defs
# 
my $beginCmdLineArgstag = "BeginCommandLineArgs";
my $endCmdLineArgstag   = "EndCommandLineArgs";
my $fileinputstag = "INPUTS:";
my $fileoutputstag = "OUTPUTS:";
my $normalizedoutputstag = "NORMALIZE_EPS_OUTPUT_OF:";
my $includegraphicstag = 'includegraphics';


$numArgs = $#ARGV + 1;
if( $numArgs < 5 )
  {
      print "Usage arguments: \n";
      print "  Name of the .cxx/.txx file (with extenstion).\n";
      print "  OTBExecsDirectoryPath \n";
      print "  Cmake file to be generated\n";
      print "  Name of the TEX file generated, so dependencies can be specified\n";
      print "  Ouput folder to store generated images\n";
      print "  Double Colon separated list of possible include directories for input images\n";
  die;
  }

@searchdir = split(/::/, $ARGV[2]);
foreach $eachpath (@searchdir)
  {
    if (-d File::Spec->canonpath($eachpath))   # if the directory is valid
    { push (@searchdirs, File::Spec->canonpath($eachpath)); }
  }
GetArgsAndFilenames( $ARGV[1], $ARGV[0], \@searchdirs, $ARGV[3], $ARGV[4], $ARGV[5]);


#
#  Subroutine for parsing each one of the .cxx files.
#  The command line args and Figure file names are returned
#
sub GetArgsAndFilenames {

  my $execpath = shift;
  my $inputfilename  = shift;
  my $searchdirs = shift;
  my $cmakefile = shift;
  my $texfile = shift;
  my $generatedPath = shift; # Where the generated output files, 
                             # after running the examples are stored
  my $source_file =  $inputfilename;
  
  my $examplefilename = File::Spec->canonpath($inputfilename);
  if (!(-e $examplefilename)) 
    {
    die "File $examplefilename does not exist.\n"; 
    }


  #Strip the path and file extension to get the exec file name.
  #Exec file anme is assumed to be the same as the source filename
  my $volume; my $directories;
  ($volume,$directories,$inputsourcefile) = File::Spec->splitpath( $inputfilename );
  $inputsourcefile =~ m/(.*)(\.cxx|\.CXX|\.txx|\.TXX)/; 
  my $execfilenamebase = $1;

  #If the paths have a trailing /, remove it.
  if ($execpath =~ /\/$/)
    {
    $execpath =~ m/(.*)\//; 
    $execpath = $1;
    }
  if ($generatedPath =~ /\/$/)
    {
    $generatedPath =~ m/(.*)\//; 
    $generatedPath = $1;
    }

  # Make the path platform independent
  my @execdirs = File::Spec->splitdir($execpath);
  $execfilename = File::Spec->catfile(@execdirs, $execfilenamebase);

  #Get the command line args from the source file
  open(INFILE, "< $examplefilename"  )  or die "Can't open $examplefilename $!";

  my $tagfound     = 0;
  my $filefound = 0;
  my $cmdLineArgs;
  my $thisline='';
  my $counter=0; 
  my $inputfileInThisLine;
  my $outputfileInThisLine;
  my @outputfilesInThisLine;
  my $artdir;
  my @outputs;
  
  #Create a .cmake file
  $cmakeFile =  File::Spec->canonpath($cmakefile);

  #Check if file exists
  if (-e $cmakeFile) 
    {
    open CMAKEFILE, "<  $cmakeFile" or die "Couldn't open $cmakeFile";
    @cmakelinesold = <CMAKEFILE>;   
    }
    
  
  #Check if there are any input files that need to be flipped.
  $generatedPath =  File::Spec->canonpath($generatedPath);
  $flipfilename = File::Spec->catfile($generatedPath,"Flipped_files.txt");
  @flippedfiles = ();
  if (-e $flipfilename)
    {
    open FLIPFILE, "< $flipfilename" or die "Could not open $flipfilename";
    @flippedfiles = <FLIPFILE>;
    close FLIPFILE;
    }

    
  #
  #Read each line and Parse the input file 
  #
  while(<INFILE>) 
    {
    $thisline=$_; 
    if ($thisline)
      {

      
      # Some of the CommandLine tags have C++ code intersparced between them.
      # The space between the tags is meant only for command line arguments and
      # dependency generation for the software guide. Below, we will weed out
      # some kinds of C++ code if found.
      # TODO: Remove this ugly hack when we get a chance
      if ( ($thisline =~ "__BORLANDC__") || ($thisline =~ "ITK_LEAN_AND_MEAN") || ($thisline =~ "#endif"))
        {  next;  }
        
        
      # If the "BeginCommandLineArgs" tag is found, set the "$tagfound" var and 
      # initialize a few variables and arrays.
      if ($thisline =~ /$beginCmdLineArgstag/)
        { 
        $tagfound = 1;
        $cmdLineArgs = '';
        @outputs = (); @inputs = (); @byproducts = (); 
        @normalizedfiles = ();
        @generatedinputfile = ();
        }
        
      elsif ($thisline =~ /$endCmdLineArgstag/)
        {
        # Add these commands to the .cmake file
        $tagfound=0;
        # Execute with command line args now.. 
        $toexecute = "$execfilename"." "."$cmdLineArgs";
        foreach $output (@outputs)
          { 

          # If we made the assumption that the input file needed for this example
          # was generated by running some other example, let us explicitly
          # state that dependency so that makefile rules fire in the right
          # order. Here we will generate CMake macros that state that all outputs
          # of this example depend on that "generated input".
          foreach $generatedinput (@generatedinputfile)
            {
            $myline = sprintf("#Looks like the figure \"%s\" was generated by another example.\n",$generatedinput);
            $myline = sprintf("#Add a dependency of \"%s\" on \"%s\".\n",$output,$generatedinput);
            push(@cmakelines, $myline);
            $myline = sprintf("ADD_GENERATED_FIG_DEPS( \"%s\" \"%s\" )\n",$output,$generatedinput);
            push(@cmakelines, $myline);
            }
         
          # For debugging purposes we will write out the command line parsed by
          # the perl script. This is the line that will be invoked from the 
          # shell to run the Example.
          $myline = sprintf("# Cmake macro to invoke: %s\n",$toexecute);
          push(@cmakelines, $myline);

          # Generate a cmake macro for the same
          $myline = sprintf("RUN_EXAMPLE( \"%s\" \"%s\" \"%s\" %s )\n",$execfilenamebase,$output, $source_file, $cmdLineArgs);
          push(@cmakelines, $myline);
          }
        if (-e $flipfilename)
          {
          # Check to see if the inputs have dependencies on files that need to be flipped. If so, the
          # output also incurs this dependency.
          CheckForFlippedImages(\@inputs, \@outputs, $flipfilename);
          CheckForFlippedImages(\@generatedinputfile, \@outputs, $flipfilename);
          }
        }
      
      #        
      #Read and parse each line of the command line args
      #
      if ($tagfound)
        {
          
        if (!($thisline =~ /$beginCmdLineArgstag/))
          {
          $_ =~ s/\/\///; 
          chomp;
          $line = $_;

          #
          #Line contains file inputs
          #
          if ($thisline =~ /$fileinputstag/)
            {
            @inputfilesInThisLine = GetInputFilesInThisLine($line);

            # Search the path tree to get the full paths of the input files.
            foreach $inputfileInThisLine (@inputfilesInThisLine)
              {
              $inputfileInThisLine =~ m/{(.*)}/;
              $inputfileInThisLine = $1;
              push(@inputfiles, $inputfileInThisLine);
              if (($inputfileInThisLine =~ /{/) || ($inputfileInThisLine =~ /}/))
                { die "\nPlease check syntax. Input/Output files must be included ".
                  "in a comma separated list and enclosed in {} as in ".
                  "INPUTS: {file1}, {file2}, .... \n";  
                }       
              $filefound=0;

              foreach $searchelement (@$searchdirs)
                {
                File::Find::find (
                sub 
                  { 
#                  if ($File::Find::name =~ /$inputfileInThisLine/) 
#                  if ($File::Find::name =~ /$inputfileInThisLine$/) 
                  if ($_ =~ /^$inputfileInThisLine$/) 
                    { 
                    # We found the file in the directory.
                    # Check to see if it is a plain file - not a directory
                    $foundfilename = $File::Find::name; 
                    $filefound = 1;
                    }
                  }, $searchelement);
                  if ($filefound)   { push(@inputs,$inputfileInThisLine); last;  }
                }

              if (!($filefound)) 
                {
                # die " File $inputfileInThisLine could not be found in the search paths supplied.";
                # We could not find the input file (used to run the example) in
                # the list of search paths provided. We will assume that the 
                # file is generated by another example. If it is not, the 
                # makefile will automatically generate an error while building.
                #
                # Assuming that file 'foo' is generated by another example, we will 
                # generate a CMake Macro to signal that the outputs of this file
                # depend on file 'foo'. It is assumed that 'foo' will be found 
                # in the directory $generatedPath.
                # 
                $foundfilename = $generatedPath.'/'.$inputfileInThisLine;
                push(@generatedinputfile, $inputfileInThisLine);
                }
              
              #Add the file to the list of command line arguments in the same order
              $cmdLineArgs = $cmdLineArgs . ' ' . File::Spec->canonpath($foundfilename);
              }
            }
            
          #Line contains file outputs
          #
          elsif ($thisline =~ /$fileoutputstag/)
            {
            @outputfilesInThisLine = GetOutputFilesInThisLine($line);
            
            foreach $outputfileInThisLine (@outputfilesInThisLine)
              {
              if ($outputfileInThisLine =~ m/{(.*)}/)
                {
                $outputfileInThisLine = $1;
                push(@outputfiles, $1);
                
                if (($outputfileInThisLine =~ /{/) || ($outputfileInThisLine =~ /}/))
                  { die "\nPlease check syntax. Input/Output files must be included ".
                    "in a comma separated list and enclosed in {} or [] as in ".
                    "OUTPUTS: {file1}, {file2}, [file3] ..... \n";  
                  }       
                
                $tmp =   $generatedPath.'/'.$outputfileInThisLine;
                $outputfiletoadd = File::Spec->canonpath($tmp);  
                  
                #Add the file to the list of command line arguments in the same order
                $cmdLineArgs = $cmdLineArgs . ' ' . $outputfiletoadd;
                push(@outputs, $outputfileInThisLine);  
                }
              elsif ($outputfileInThisLine =~ m/\Q[\E(.*)\Q]\E/)
                { 
                $outputfileInThisLine = $1;
                push(@outputfiles, $1);
                
                if (($outputfileInThisLine =~ /{/) || ($outputfileInThisLine =~ /}/))
                  { die "\nPlease check syntax. Input/Output files must be included ".
                    "in a comma separated list and enclosed in {} or [] as in ".
                    "OUTPUTS: {file1}, {file2}, [file3] ..... \n";  
                  }       
                
                $tmp =   $generatedPath.'/'.$outputfileInThisLine;
                push(@byproducts, $outputfileInThisLine);  
                push(@outputs,$outputfileInThisLine);
                }
              }
            }
        
          elsif ($thisline =~ /$normalizedoutputstag/)
            {
            @normalizedfilesInThisLine = GetNormalizedFilesInThisLine($line);
            foreach $normalizedfileInThisLine (@normalizedfilesInThisLine)
              {
              if ($normalizedfileInThisLine =~ m/{(.*)}/)
                {
                $normalizedfileInThisLine = $1;
                if (($normalizedfileInThisLine =~ /{/) || ($normalizedfileInThisLine =~ /}/))
                  { die "\nPlease check syntax. files must be included ".
                    "in a comma separated list and enclosed in {} or [] as in ".
                    "NORMALIZE_EPS_OUTPUT_OF: {file1}, {file2}, ... \n";  
                  }       
                push(@normalizedfiles, $normalizedfileInThisLine);  
                }
              }
            }
            
 
          else  #Not a file input, just a command line arg
            {
            $thisLineContains = join(' ', split); 
            $cmdLineArgs = $cmdLineArgs . ' ' . $thisLineContains;
            }    
          }
        }

        
      #
      #Parse file to see the list of eps files generated (through the includegraphics statement)
      #
      if ($thisline =~ /$includegraphicstag/)
        {
        GetLatexFiles($thisline,\@lateximgfile,\@lateximgfilebase);
        }
      }
    }

  
  #
  # Generate CMAKE macros to convert using ImageMagick's convert exec
  #
  ($v,$examplesdir,$f) = File::Spec->splitpath($cmakefile);  my $ctr=0;
  $examplesdir = File::Spec->canonpath($examplesdir);
  push(@iofiles,@outputfiles);   push(@iofiles,@inputfiles);
  foreach $lateximgFile (@lateximgfile)
    {
    $lateximgFilebase = $lateximgfilebase[$ctr++].'.';  
    foreach $cmdlineoutfile (@iofiles)
      {
      if (!(grep(/^$cmdlineoutfile$/, @byproducts)))
        { $filepath = $generatedPath;  }
      else {  $filepath = $examplesdir; }
      print @byrpoducts;

      $substring1 = $cmdlineoutfile;
      $substring1 =~ m/(.*)\./; $substring1 = $1;
      $substring2 = $lateximgFilebase;
      $substring2 =~ m/(.*)\./; $substring2 = $1;
      if ($substring1 eq $substring2)
        {
        # One of the files on the command line matches the file being included using \includegraphicstag
        
        if (ShouldBeFlipped($cmdlineoutfile, $flipfilename))
          {
          if (IsAnInputFile($cmdlineoutfile,$searchdirs,\$path))
            { $myline = sprintf("CONVERT_AND_FLIP_INPUT_IMG( \"%s\" \"%s\" \"%s\" )\n",$cmdlineoutfile,$lateximgFile,$path); }
          else
            { 
            if (ShouldBeNormalized($cmdlineoutfile, \@normalizedfiles))
              {
              $myline = sprintf("CONVERT_AND_FLIP_AND_NORMALIZE_IMG( \"%s\" \"%s\" \"%s\" )\n",$cmdlineoutfile,$lateximgFile,$filepath); 
              }
            else
              { 
              $myline = sprintf("CONVERT_AND_FLIP_IMG( \"%s\" \"%s\" \"%s\" )\n",$cmdlineoutfile,$lateximgFile,$filepath); 
              }
            }
          }
        else
          {
          my $ext = lc ( ($cmdlineoutfile =~ m/([^.]+)$/)[0] );
          
          if (IsAnInputFile($cmdlineoutfile,$searchdirs,\$path))
            {
            $myline = sprintf("CONVERT_INPUT_IMG( \"%s\" \"%s\" \"%s\" )\n",$cmdlineoutfile,$lateximgFile,$path); 
            }
          else
            { 
            if (ShouldBeNormalized($cmdlineoutfile, \@normalizedfiles))
              {
              $myline = sprintf("CONVERT_AND_NORMALIZE_IMG( \"%s\" \"%s\" \"%s\" )\n",$cmdlineoutfile,$lateximgFile,$filepath); 
              }
            else
              {
              $myline = sprintf("CONVERT_IMG( \"%s\" \"%s\" \"%s\" )\n",$cmdlineoutfile,$lateximgFile,$filepath); 
              }
            }
          }
        push(@cmakelines, $myline);
        $myline = sprintf("ADD_DEP_TEX_ON_EPS_FIGS( \"%s\" \"%s\" )\n",$texfile,$lateximgFile);                 
        push(@cmakelines, $myline);
        }
      }
    }

  # Compare CMake file present in the directory and the one currently generated.
  # Check if they are the same. If they are the same do not write one.. This
  # is to get around a problem the CMake problem as follows: You cannot generate
  # a .cmake file through a custom command and include it in the same CMakeLists.txt
  # file. This creates a circular dependency. Since we don't have a dependency that
  # drives the generation of the .cmake file (its is generated unconditionally), we 
  # check here if the .cmake file to be written is the same as the one already present.
  # If it is, we do not write a new one. This avoids unnecessary rebuilding.
  my $str1 = join('^G', @cmakelines);
  my $str2 = join('^G', @cmakelinesold);
  $isequal = 0;
  if ($str1 eq $str2) { $isequal = 1; } 

  if ( !( $isequal ))
    {
    $cmakefilehandle = new IO::File $cmakeFile, "w";
    if (!(defined $cmakefilehandle)) { die "Could not open file $cmakeFile\n"; }
    foreach $cmakeline (@cmakelines) {
      $cmakefilehandle->printf("%s",$cmakeline);
      }
    }

  UpdateTableFile($generatedPath, \@iofiles);
  }



#
# Check if the input image in the command line arg is one of the
# flipped ones... if so set the output image as one to be flipped
# ... legacy SoftwareGuide problem
# 
sub CheckForFlippedImages{
  my $inps = shift;
  my $outs = shift;
  my $flipfilename = shift;

  if (-e $flipfilename)
    {
    open FLIPFILE, "< $flipfilename" or die "Could not open $flipfilename";
    while (<FLIPFILE>) { push(@flippedfiles,split); }
    close FLIPFILE;
    }
  else { return 0;  }

  my $matchfound=0;
  
  foreach $inpFile (@$inps)
    { 
    if ($inpFile =~  m/(.*)\./) { $inpFile = $1;  }
    for ($i=0;$i<@flippedfiles;$i++)
      { 
      chomp($flippedfiles[$i]);
      $flippedfiles[$i] =~ s/ //;
      $flippedfiles[$i] =~ m/(.*)\./;
      }
    @matches = grep(/^$inpFile$/, @flippedfiles);
    if (@matches) 
      {
      AddFilesToListOfFlippedFiles(\@$outs, $flipfilename);
      $matchfound=1;
      }
    }
  return $matchfound;
}
  
  
#
# Keep a file containing a list of flipped images... 
# legacy SoftwareGuide problem
# 
sub  AddFilesToListOfFlippedFiles{
  my $outs = shift;
  my $flipfilename = shift;

  if (-e $flipfilename)
    {
    open FLIPFILE, "< $flipfilename" or die "Could not open $flipfilename";
    while (<FLIPFILE>) { push(@flippedfiles,split); }
    close FLIPFILE;
    }
  else { return;  }
  
  foreach $outFile (@$outs)
    { 
    for ($i=0;$i<@flippedfiles;$i++)
      { 
      chomp($flippedfiles[$i]);
      $flippedfiles[$i] =~ s/ //;
      $flippedfiles[$i] =~ m/(.*)\./;
      }
    if ($outFile =~  m/(.*)\./) { $outFile = $1;  }
    @matches = grep(/^$outFile$/, @flippedfiles);
    if (!(@matches)) 
      {
      if (-e $flipfilename)
        {
        open FLIPFILE, ">> $flipfilename" or die "Could not open $flipfilename";
        printf FLIPFILE "$outFile ";
        close FLIPFILE;
        }
      }
    }
  }


#
# Check to see if the image is one that has been set as one to be flipped  
# 
sub ShouldBeFlipped{
  my $file = shift;
  my $flipfilename = shift;

  if (-e $flipfilename)
    {
    open FLIPFILE, "< $flipfilename" or die "Could not open $flipfilename";
    while (<FLIPFILE>) { push(@flippedfiles,split); }
    close FLIPFILE;
    }
  else { return 0;  }

  for ($i=0;$i<@flippedfiles;$i++)
    { 
    chomp($flippedfiles[$i]);
    $flippedfiles[$i] =~ s/ //;
    $flippedfiles[$i] =~ m/(.*)\./;
    }

  if ($file =~  m/(.*)\./) { $file = $1;  }
  @matches = grep(/^$file$/, @flippedfiles);
  if (@matches) { return 1; }
  else { return 0;  }
}

    
#
# Parse the line to see if there are any files included in the latex doc
# with the \includegraphics method. If so, add it to the @lateximgfile array.
# 
sub GetLatexFiles{
  my $thisline = shift;
  my $lateximgfile = shift;
  my $lateximgfilebase = shift;
  
  $thisline =~ m/$includegraphicstag(.*)/; $thisline = $1;
  $thisline =~ m/{(.*)}/;    $thisline = $1;
  $thisline =~ s/ //; 
  $lateximgFile = $1;
  push (@$lateximgfile, $lateximgFile);
  $lateximgFile =~ m/(.*)\./;
  $lateximgFilebase = $1;
  push (@$lateximgfilebase, $lateximgFilebase);
}

sub GetOutputFilesInThisLine{
  my $line = shift;

  $line =~ s/$fileoutputstag//; #Strip the tag away
  # squish more than one space into one
  $line =~ tr/ //s; 
  $line =~ s/^ *//; #strip leading and trailing spaces
  $line =~ s/ *$//; 
  @outputfilesInThisLine = split(/,/,$line);
  return @outputfilesInThisLine;
}

sub GetInputFilesInThisLine{
  my $line = shift;
  $line =~ s/$fileinputstag//; #Strip the tag away
  # squish more than one space into one
  $line =~ tr/ //s; 
  $line =~ s/^ *//; #strip leading and trailing spaces
  $line =~ s/ *$//;
  @inputfilesInThisLine = split(/,/,$line);
  return @inputfilesInThisLine;
}


sub GetNormalizedFilesInThisLine{
  my $line = shift;
  $line =~ s/$normalizedoutputstag//; #Strip the tag away
  # squish more than one space into one
  $line =~ tr/ //s; 
  $line =~ s/^ *//; #strip leading and trailing spaces
  $line =~ s/ *$//; 
  @normalizedfilesInThisLine = split(/,/,$line);
  return @normalizedfilesInThisLine;
}




sub  UpdateTableFile{
  my $generatedPath = shift; my $iofiles = shift;
  if (!(@$iofiles)) { return; } # No generated io files to update 
  $GenFilename = File::Spec->catfile($generatedPath,"GeneratedFiles.txt");
  
  # Get current list
  if (-e $GenFilename)
    {
    open GENFILEHANDLE, "< $GenFilename" or die "Could not open $flipfilename";
    while (<GENFILEHANDLE>) { push(@generatedfiles,split /;/); }
    close GENFILEHANDLE;    
    }

  foreach $ioFile (@$iofiles)
    {
    if ($ioFile =~  m/(.*)\./) { $ioFile = $1;  }
    if ($ioFile) {
      $ioFile = $ioFile.'.*';
      @matches = grep(/^$ioFile$/, @generatedfiles);
      if (!(@matches)) 
        {
        open GENFILEHANDLE, ">> $GenFilename" or die "Could not open $flipfilename";
        printf GENFILEHANDLE "$ioFile;";
        close GENFILEHANDLE;
        }
      }
    }
  }
  

sub ShouldBeNormalized{
  my $file = shift; my $normalizedFiles = shift;
  my $toBeNormalized = 0;  

  if (grep(/^$file$/, @$normalizedFiles))
    { $toBeNormalized = 1;  }
  return $toBeNormalized;
}
    

# The subroutine accepts three arguments.
# - $file -      file to be searched
# - $datapaths - paths to search $file in. This is an array, containing
#                one or more paths. Each path in this array is searched
#                recursively, ie all subdirectories in each of those
#                paths are searched.
# - \$path_ptr - A reference to a path string. This is the path containing 
#                the $file, if found. The trailing "/" is not present in the 
#                path. So on windows the returned variable will look like
#                C:/ITK/src/Insight/Nightly/Examples/Data
#                On *nix, it will look like
#                /ITK/src/Insight/Nightly/Examples/Data
# - Returns    - 0 if $file is not found. 1 if $file is found               
# 
# The function searches to see of '$file' is found in the paths specified by
# '$datapaths'. If found, the return value is 1, otherwise it is 0. 
# 
sub IsAnInputFile{
  my $file = shift; my $datapaths = shift;
  my $path_ptr = shift;
  my $isAnInputFile = 0;

  foreach $datapath (@$datapaths)
    {  
    File::Find::find (
    sub 
      { 
      if ($File::Find::name =~ /$file/) 
        { 
        # We found the file in the directory.
        # Check to see if it is a plain file - not a directory
        $$path_ptr = File::Spec->canonpath($datapath); 
        $isAnInputFile = 1;
        }
      }, $datapath);
      if ($isAnInputFile) { last; }
    }
  return $isAnInputFile;
}
 
  