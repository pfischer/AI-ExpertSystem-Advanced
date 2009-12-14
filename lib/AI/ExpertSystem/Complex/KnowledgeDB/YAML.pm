#
# AI::ExpertSystem::Complex::KnowledgeDB::YAML
#
# Author(s): Pablo Fischer (pfischer@cpan.org)
# Created: 12/13/2009 16:12:43 PST 16:12:43
package AI::ExpertSystem::Complex::KnowledgeDB::YAML;

use Moose;
use YAML::Syck;

extends 'AI::ExpertSystem::Complex::KnowledgeDB::Base';

=head1 Attributes

=over 4

=item B<filename>

YAML filename to read

=back

=cut
has 'filename' => (
        is => 'rw',
        isa => 'Str',
        required => 1);

# Called when the object gets created
sub BUILD {
    my ($self) = @_;

    my $data = LoadFile($self->{'filename'});
    if (defined $data->{'rules'}) {
        $self->{'rules'} = $data->{'rules'}
    } else {
        confess "Couldn't find any rules in $self->{'filename'}";
    }
}

1;

