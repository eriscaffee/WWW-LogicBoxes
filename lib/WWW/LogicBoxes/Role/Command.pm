package WWW::LogicBoxes::Role::Command;

use Moose::Role;
use MooseX::Params::Validate;

use WWW::LogicBoxes::Types qw( HashRef Str );

use JSON qw( decode_json );

use Try::Tiny;
use Carp;

with 'WWW::LogicBoxes::Role::Command::Raw';
requires 'response_type';

# VERSION
# ABSTRACT: Submission of LogicBoxes Commands

# Used to force json as the response_type and restore the existing type afterwards
around submit => sub {
    my $orig = shift;
    my $self = shift;
    my $args = shift;

    my $current_response_type = $self->response_type;

    my $response;
    try {
        if( $current_response_type ne 'json' ) {
            $self->response_type('json');
        }

        $response = $self->$orig( $args );
    }
    catch {
        croak $_;
    }
    finally {
        if($self->response_type ne $current_response_type) {
            $self->response_type($current_response_type);
        }
    };

    return $response;
};

sub submit {
    my $self   = shift;
    my (%args) = validated_hash(
        \@_,
        method => { isa => Str },
        params => { isa => HashRef },
    );

    my $response;
    try {
        my $method = $args{method};
        my $raw_json = $self->$method( $args{params} );

        if($raw_json =~ /^\d+$/) {
            # When just an id is returned, JSON is not used
            $response = { id => $raw_json };
        }
        else {
            $response = decode_json( $raw_json );
        }
    }
    catch {
        croak "Error Making LogicBoxes Request: $_";
    };

    if(exists $response->{status} && $response->{status} eq "ERROR") {
        croak $response->{message};
    }

    return $response;
}

1;
