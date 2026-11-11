#!/usr/bin/perl
# usage: perl sdf_flatten.pl in.sdf out.sdf
open(IN, "<", $ARGV[0]) or die "cannot open $ARGV[0]";
open(OUT, ">", $ARGV[1]) or die "cannot write $ARGV[1]";
my ($ni, $nc) = (0, 0);
while (my $line = <IN>) {
    if ($line =~ /^(\s*\(INSTANCE\s+)(\S+?)(\s*\)\s*)$/s) {
        my ($a, $p, $b) = ($1, $2, $3);
        if ($p =~ m{/}) { $p =~ s{/}{\\/}g; $ni++; }
        $line = $a . $p . $b;
    } elsif ($line =~ /^(\s*\(INTERCONNECT\s+)(\S+)(\s+)(\S+)(\s.*)$/s) {
        my ($a, $p1, $s, $p2, $r) = ($1, $2, $3, $4, $5);
        foreach my $p ($p1, $p2) {
            if ($p =~ m{^(.*)/([^/]*)$}) {
                my ($h, $t) = ($1, $2);
                $h =~ s{/}{\\/}g;
                $p = "$h/$t";
            }
        }
        $line = $a . $p1 . $s . $p2 . $r;
        $nc++;
    }
    print OUT $line;
}
close(IN); close(OUT);
print "INSTANCE lines converted: $ni, INTERCONNECT lines converted: $nc\n";
