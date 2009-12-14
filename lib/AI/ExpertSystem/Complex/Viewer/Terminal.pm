#
# AI::ExpertSystem::Complex::Viewer::Terminal
#
# Author(s): Pablo Fischer (pfischer@cpan.org)
# Created: 12/13/2009 15:44:23 PST 15:44:23
package AI::ExpertSystem::Complex::Viewer::Terminal;

=head1 NAME

AI::ExpertSystem::Complex::Viewer::Terminal - Viewer for terminal

=head1 DESCRIPTION

Extends from L<AI::ExpertSystem::Complex::Viewer::Base> and its main purpose is
to interact with a (console) terminal.

=cut
use Moose;
use Term::ReadLine;

extends 'AI::ExpertSystem::Complex::Viewer::Base';

=head1 Attribtes

=over 4

=item B<readline>

A L<Term::ReadLine> instance.

=back

=cut
has 'readline' => (
        is => 'ro',
        isa => 'Term::ReadLine');

=head1 Methods

=head2 B<debug($msg)>

Basically just does a print but prepends the "DEBUG" string to the message.

=cut
sub debug {
    my ($self, $msg) = @_;
    print "DEBUG: $msg\n";
}

=head2 B<print($msg)>

Just does a print of the given message.

=cut
sub print {
    my ($self, $msg) = @_;
    print "$msg\n";
}

=head2 B<print_error($msg)>

Will prepend the "ERROR:" word to the given message and then will call
C<print()>.

=cut
sub print_error {
    my ($self, $msg) = @_;
    $self->print("ERROR: $msg");
}

=head2 B<ask($message, @options)>

Will be used to ask the user for some information. It will receive a string,
the question to ask and an array of all the possible options.

Please return only one option and this should be any of the ones listed in
C<@options> cause otherwise L<AI::ExpertSystem::Complex> will die.

=cut
sub ask {
    my ($self, $msg, $options) = @_;

    my $reply = $self->{'readline'}->get_reply(
            prompt => $msg,
            choices => $options);
    return $reply;
}

# Called when the object is created
sub BUILD {
    my ($self) = @_;

    $self->{'readline'} = Term::ReadLine->new('questions');
}
1;
