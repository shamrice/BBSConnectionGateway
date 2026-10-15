package BBSConnectionGateway;

use v5.38;
use feature qw(try);

use threads ('exit' => 'threads_only');

use Carp;
use DateTime;
use Data::Dumper;

use FindBin qw($Bin);
use lib("$Bin/../lib");

use BBSConnectionGateway::Configuration::Config;
use BBSConnectionGateway::Log::Logger;
use BBSConnectionGateway::Log::LogQueue;
use BBSConnectionGateway::Connector::Modem::ModemConnectionHandler;
use BBSConnectionGateway::Connector::Network::NetworkConnectionHandler;

no warnings qw(experimental::try);

our $VERSION = '0.2';
our $BOOT_DATE = DateTime->now;


sub new {
    my ($class, %args) = shift;

    my $config_file = $args{config};
    my $config = BBSConnectionGateway::Configuration::Config->new(package => __PACKAGE__);
    my $log = BBSConnectionGateway::Log::Logger->new(name => $class);
    my $conn_lock_file = $config->get('connection_lock_file', '../conn.lock');

    my $self = {
        config => $config,
        log => $log,
        conn_lock_file => $conn_lock_file,
    };

    return bless($self, $class);
}

sub _config {
    return shift->{config};
}

sub _log {
    return shift->{log};
}


sub _conn_lock_file {
    return shift->{conn_lock_file};
}



sub run {
    my ($self) = @_;
    $self->_log->info("BBSConnectionGateway starting...");

    my $log_queue_thread = threads->new(sub {
        BBSConnectionGateway::Log::LogQueue::log_queue_handler_thread;
    });


    if (-e $self->_conn_lock_file) {
        $self->_log->warn("Connection lock file exists on start up! Deleting existing file...");
        unlink($self->_conn_lock_file) or do {
            $self->_log->fatal("Failed to delete lock file! :: $!");
            return;
        };
    }

    if ($self->_config->get('dialup_enabled', 0)) {
        $self->_log->info("Dial up enabled. Starting dial up service thread.");
        my $dialup_thread = threads->new(sub {
            while (1) {
                try {
                    my $modem_handler = BBSConnectionGateway::Connector::Modem::ModemConnectionHandler->new(conn_lock_file => $self->_conn_lock_file);
                    $modem_handler->run;
                } catch ($dialup_ex) {
                    $self->_log->fatal("Fatal error creating/running dialup thread. Sleeping 5 minutes and trying again... :: ERROR: $dialup_ex");
                    sleep 300; # sleep 5 minutes
                }
            }
        });
    }

    my $network_thread = threads->new(sub {
        while (1) {
            try {
                my $network_handler = BBSConnectionGateway::Connector::Network::NetworkConnectionHandler->new(conn_lock_file => $self->_conn_lock_file);
                $network_handler->run;
            } catch ($network_ex) {
                $self->_log->fatal("Fatal error in network handler thread. Sleeping 5 minutes and trying again... :: ERROR: $network_ex");
                sleep 300;
            }
        }
    });

    $_->join foreach (threads->list(threads::all));

    $self->_log->fatal("SHUTDOWN COMPLETE");
    return;
}

1;
