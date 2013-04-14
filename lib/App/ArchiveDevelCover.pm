package App::ArchiveDevelCover;
use 5.010;
use Moose;
use MooseX::Types::Path::Class;
use DateTime;
use File::Copy;
use HTML::TableExtract;
use Data::Dumper;$Data::Dumper::Indent=1;

# ABSTRACT: Archive Devel::Cover reports
our $VERSION = '1.002';

with 'MooseX::Getopt';

=pod

What does this package actually do?

On the first run, it copies the .html files created by a run of Devel::Cover
into a subdirectory named 'archive/<DateTime>/' underneath that designated by
the value of the 'to' option.  Those files include:

    archive/<DateTime>/coverage.html
    archive/<DateTime>/blib-lib-Data-Dumper-pm.html
    archive/<DateTime>/blib-lib-Data-Dumper-pm--branch.html
    archive/<DateTime>/blib-lib-Data-Dumper-pm--condition.html
    archive/<DateTime>/blib-lib-Data-Dumper-pm--subroutine.html

It also creates the first version of the archive summary .html file:

    archive/index.html

On the second run, it creates another 'archive/<2nd_DateTime>/'
subdirectory and copies the 5 .html files into it.  It then updates 'archive/index.html' by adding the percentages from the second run
to the top of the chart.  In addition, it creates the first instance of the
diff .html file:

    archive/<2nd_DateTime>/diff.html

On the third and subsequent runs, it presumably (I haven't tried this yet),
creates yet another 'archive/<3rd_DateTime>' subdirectory, copies 5 .html
files into it, updates 'archive/index.html', and creates the next instance of
the diff .html file:

    archive/<3rd_DateTime>/diff.html  # must verify directory

So, the program has the potential to store *a lot of* .html files as well as a
.diff html file for each run of the program.  Only the 'archive/index.html'
file appears to be modified in place -- but that is probably the most
important output file of all, as it is the one that logs progress over time.

=cut

# 'from', 'to': Path::Class::Dir objects
has [qw(from to)] => (is=>'ro',isa=>'Path::Class::Dir',coerce=>1,required=>1,);

# 'project': name of project for which coverage has been calculated (#
# improve)
has 'project' => (is => 'ro', isa=>'Str', lazy_build=>1);
sub _build_project {
    my $self = shift;
    my @list = $self->from->parent->dir_list;
    return $list[-1] || 'unknown project';
}

# 'coverage': array ref of coverage criteria selected; defaults to Domm's
# choices
has 'coverage' => (
    is          => 'ro',
    isa         => 'ArrayRef',
    default     => sub { [qw(statement subroutine total)] },
);

# 'coverage_html': Path::Class::File object for coverage.html
has 'coverage_html' => (is=>'ro',isa=>'Path::Class::File',lazy_build=>1,traits=> ['NoGetopt']);
sub _build_coverage_html {
    my $self = shift;
    if (-e $self->from->file('coverage.html')) {
        return $self->from->file('coverage.html');
    }
    else {
        say "Cannot find 'coverage.html' in ".$self->from.'. Aborting';
        exit;
    }
}

# runtime: DateTime object; needs to be obtained from database rather than
# from coverage.html
has 'runtime' => (is=>'ro',isa=>'DateTime',lazy_build=>1,traits=> ['NoGetopt'],);
sub _build_runtime {
    my $self = shift;
    return DateTime->from_epoch(epoch=>$self->coverage_html->stat->mtime);
}

# 'archive_html': Path::Class::File object; creates the archive/index.html
# file if it does not already exist
has 'archive_html' => (is=>'ro',isa=>'Path::Class::File',lazy_build=>1,traits=> ['NoGetopt']);
sub _build_archive_html {
    my $self = shift;
    unless (-e $self->to->file('index.html')) {
        my $tpl = $self->_archive_template;
        my $fh = $self->to->file('index.html')->openw;
        print $fh $tpl;
        close $fh;
    }
    return $self->to->file('index.html');
}

# 'archive_db': Path::Class::File object; returns path to archive_db (but file
# does not necessarily exist)
has 'archive_db' => (is=>'ro',isa=>'Path::Class::File',lazy_build=>1,traits=> ['NoGetopt']);
sub _build_archive_db {
    my $self = shift;
    return $self->to->file('archive_db');
}

# 'previous_stats': reference to 4-element array
has 'previous_stats' => (is=>'ro',isa=>'ArrayRef',lazy_build=>1,traits=>['NoGetopt']);
sub _build_previous_stats {
    my $self = shift;
    if (-e $self->archive_db) {
        my $dbr = $self->archive_db->openr;
        my @data = <$dbr>; # probably better to just get last line...
        my @prev = split(/;/,$data[-1]);
        return \@prev;
    }
    else {
        return [undef,0,0,0];
    }
}

# 'diff_html': Path::Class::File object returning path to diff.html
has 'diff_html' => (is=>'ro',isa=>'Path::Class::File',lazy_build=>1,traits=> ['NoGetopt']);
sub _build_diff_html {
    my $self = shift;
    return $self->to->subdir($self->runtime->iso8601)->file('diff.html');
}

########## PUBLIC METHODS ##########

sub run {
    my $self = shift;
    my $rv = $self->archive;
    exit unless defined $rv;
    $self->generate_diff;
    $self->update_index;
}

sub archive {
    my $self = shift;

    my $from = $self->from;
    my $target = $self->to->subdir($self->runtime->iso8601);

    if (-e $target) {
        say "This coverage report has already been archived.";
        return;
    }

    $target->mkpath;
    my $target_string = $target->stringify;

    while (my $f = $from->next) {
        next unless $f=~/\.(html|css)$/;
        copy($f->stringify,$target_string) || die "Cannot copy $from to $target_string: $!";
    }

    say "archived coverage reports at $target_string";
    return $target_string;
}

sub generate_diff {
    my $self = shift;

    my $prev = $self->previous_stats;
    return unless $prev->[0];

    my $te_new = HTML::TableExtract->new( headers =>
        [ 'file', @{$self->coverage} ]
    );
    $te_new->parse(scalar $self->coverage_html->slurp);
    my $new_rows =$te_new->rows;
    my $te_old = HTML::TableExtract->new( headers =>
        [ 'file', @{$self->coverage} ]
    );
    $te_old->parse(scalar $self->to->subdir($prev->[0])->file('coverage.html')->slurp);
    my $old_rows =$te_old->rows;

    my %diff;
    foreach my $row (@$new_rows) {
        my $file =shift(@$row);
        $diff{$file}=$row;
    }

    foreach my $row (@$old_rows) {
        my $file =shift(@$row);
        push(@{$diff{$file}},@$row);
    }

    my @output;
    foreach my $file (sort keys %diff) {
        my $data = $diff{$file};

        my $line = qq{\n<tr><td>$file</td>};
        foreach my $i (0,1,2) {
            my $nv = $data->[$i] || 0;
            my $ov = $data->[$i+3] || 0;
            my $display = "$ov&nbsp;-&gt;&nbsp;$nv";
            if ($nv == $ov) {
                $line.=qq{<td>$display</td>};
            }
            elsif ($nv > $ov) {
                $line.=$self->td_style(100,$display);
            }
            else {
                $line.=$self->td_style(0,$display);
            }
        }
        $line.="</tr>";
        push(@output,$line);
    }
    my $table = join("\n",@output);
    my $tpl = $self->_diff_template;
    $tpl=~s/DATA/$table/;

    my $fh = $self->diff_html->openw;
    print $fh $tpl;
    close $fh;
}

sub update_index {
    my $self = shift;

#    my $te = HTML::TableExtract->new( headers => $self->coverage );
#    $te->parse(scalar $self->coverage_html->slurp);
#    my $rows =$te->rows;
#    my $last_row = $rows->[-1];

#    $self->update_archive_html($last_row);
    # We need $last_row to be an array ref with the NNN.n% for statement,
    # branch, condition, subroutine, pod, time, total (or whatever the order
    # is)
    $self->update_archive_db($last_row);
}

########## INTERNAL METHODS #########

sub update_archive_html {
    my ($self, $last_row) = @_;

    my $prev_stats = $self->previous_stats;
    my $runtime = $self->runtime;
    my $date = $runtime->ymd('-').' '.$runtime->hms;
    my $link = "./".$runtime->iso8601."/coverage.html";
    my $diff = "./".$runtime->iso8601."/diff.html";

    my $new_stat = qq{\n<tr><td><a href="$link">$date</a></td><td><a href="$diff">diff</a></td>};
    foreach my $val (@$last_row) {
        $new_stat.=$self->td_style($val);
    }
    my $prev_total = $prev_stats->[3];
    my $this_total = $last_row->[-1];
    if ($this_total == $prev_total) {
        $new_stat.=qq{<td class="c3">=</td>};
    }
    elsif ($this_total > $prev_total) {
        $new_stat.=qq{<td class="c3">+</td>};
    }
    else {
        $new_stat.=qq{<td class="c0">-</td>};
    }

    $new_stat.="</tr>\n";

    my $archive = $self->archive_html->slurp;
    $archive =~ s/(<!-- INSERT -->)/$1 . $new_stat/e;

    my $fh = $self->archive_html->openw;
    print $fh $archive;
    close $fh;

    unless (-e $self->to->file('cover.css')) {
         copy($self->from->file('cover.css'),$self->to->file('cover.css')) || warn "Cannot copy cover.css: $!";
    }
}

sub update_archive_db {
    my ($self, $last_row) = @_;
    my $dbw = $self->archive_db->open(">>") || warn "Can't write archive.db: $!";
    say $dbw join(';',$self->runtime->iso8601,@$last_row);
    close $dbw;
}

sub td_style {
    my ($self, $val, $display) = @_;
    $display //=$val;
    my $style;
    given ($val) {
        when ($_ <  75) { $style = 'c0' }
        when ($_ <  90) { $style = 'c1' }
        when ($_ <  100) { $style = 'c2' }
        when ($_ >= 100) { $style = 'c3' }
    }
    return qq{<td class="$style">$display</td>};
}

sub _archive_template {
    my $self = shift;
    my $name = $self->project;
    $self->_page_template(
        "Test Coverage Archive for $name",
        q{
<table>
<tr><th>Coverage Report</th><th>diff</th><th>stmt</th><th>sub</th><th>total</th><th>Trend</th></tr>
<!-- INSERT -->
</table>
        });
}

sub _diff_template {
    my $self = shift;
    my $name = $self->project;
    $self->_page_template(
        "Test Coverage Diff for $name",
        q{
<table>
<tr><th>File</th><th>stmt</th><th>sub</th><th>total</th></tr>
DATA
</table>
        });
}

sub _page_template {
    my ($self, $title, $content) = @_;

    my $name = $self->project;
    my $class = ref($self);
    my $version = $class->VERSION;
    return <<"EOTMPL";
<!DOCTYPE html
     PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
     "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<!-- This file was generated by $class version $version -->
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8"></meta>
    <meta http-equiv="Content-Language" content="en-us"></meta>
    <link rel="stylesheet" type="text/css" href="cover.css"></link>
    <title>Test Coverage Archive for $name</title>
</head>
<body>

<body>
<h1>$title</h1>

$content

<p>Generated by <a href="http://metacpan.org/module/$class">$class</a> version $version.</p>

</body>
</html>
EOTMPL

}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 SYNOPSIS

Backend for the C<archive_devel_cover.pl> command. See L<archive_devel_cover.pl> and/or C<perldoc archive_devel_cover.pl> for details.

