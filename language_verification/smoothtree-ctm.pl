#!/usr/local/bin/perl5 -w

$tree_name=$ARGV[0];
$ctm_name=$ARGV[1];

&read_tree;

open (CTM_FILE, $ctm_name) || die "cannot open ctm file $ctm_name";
while (<CTM_FILE>) {
  $line = $_;

  if ($line =~ /^;/ ) {
    print $line;
  }
  else {
    @f=split(/\s+/, $line);
#    if ($line =~ /^([.\d]+)$/ ) {
      $orig_x=$f[5];
      #    print "$1\n";
      
    $i=1;
    until ($orig_x <= $x[$i]) {
      $i=$i+1;
    }
    

    $dx=($orig_x - $x[$i-1]);
    $dy=$dx * $slope{$x[$i]};
    $new_y=$y_ave{$x[$i-1]}+ $dy;

#    print "$i $orig_x   dx $dx dy $dy   $y{$x[$i]} $new_y\n";
#    print "$orig_x $y{$x[$i]}\n";
#    print "$orig_x $new_y\n";
     printf "%s %s %.2f %.2f %10s %f\n", $f[0], $f[1], $f[2], $f[3], $f[4], $new_y;
  }
}

exit;

sub read_tree {

  open (TREE_FILE, $tree_name) || die "cannot open tree file $tree_name";
  while (<TREE_FILE>) {
    $line = $_;
    chomp $line;
    # in the R1.2.1 the lines look like:
    # 4) confidence < 0.660969 5511  7383 F ( 0.39249 0.60751 )  
    # in the R0.61 the lines look like:
    # 4) confidence<0.654153 8386 10950 F ( 0.35953 0.64047 )  

    # normalise to old format
    $line =~ s/confidence\s*([<>])\s*/confidence$1/;

    @fields = split (/ +/, $line);
    #  printf "%s\n", $fields[2];
    if ( $fields[2] =~ /^confidence
	 ([<>])
	 ([\d.]+)
	 $/x ) {
      
      if ($1 eq "<") {
	push(@x, $2);
	if ($fields[$#fields] eq "*") {
	  $y{$2}=$fields[7];
	}
      }
      elsif ($1 eq ">") {  #  ">"
	if ($fields[$#fields] eq "*") {
	  $next_y{$2}=$fields[7];
	}
      }
      else {
        die "parse error! in line $line";
      }
    }
    else {  # root node
      #    print "skipped: |$line|\n";
    }
  }
  
  push (@x, 0.0);
  $y{0.0}=0.0;
  push (@x, 1.0);

  @x=sort (@x);
  

  # set $y{$x} from tree
  $prev_i=0.0;
  foreach $i (@x) {
    if (!defined ($y{$i})) {
      $y{$i}=$next_y{$prev_i};
    }
#    print "$i  $y{$i}\n";
    $prev_i=$i;
  }

  # obsolete
#  $x1=0.0;
#  foreach $x2 (@x) {
#    if ($x2>0.0) {
#      $slope{$x2}= ($y{$x2} - $y{$x1}) /($x2 - $x1);
#      $x1=$x2;
#      #      print "$slope{$x2} \n";
#    }
#  }

  # set $y_ave{$x} to average in each step
  $x1=0.0;
  foreach $x2 (@x) {
    if ($x2>0.0) {
      
      $y_ave{$x1}= ($y{$x2}+$y{$x1})/2;
      $x1=$x2;
    }
  }
  $y_ave{1.0}=($y{1.0}+1.0)/2;

#  foreach $yi (sort(keys(%y_ave))) {
#    print "$yi $y_ave{$yi}\n";
#  }
#  print "----\n";


  # calc slope for each piece and store in at right border x-coord
  $x1=0.0;
  foreach $x2 (@x) {
    if ($x2>0.0) {
      $slope{$x2}= ($y_ave{$x2} - $y_ave{$x1}) /($x2 - $x1);
      $x1=$x2;
#      print "x2 $x2 $slope{$x2} \n";
    }
  }

#  print "=========\n";

  close (TREE_FILE) || die "cannot close tree file"; 
}
