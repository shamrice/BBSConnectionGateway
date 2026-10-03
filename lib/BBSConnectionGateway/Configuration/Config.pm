package BBSConnectionGateway::Configuration::Config;

use v5.34;

use Carp;
use Config::Tiny;
use FindBin qw($Bin);

sub new {
    my ($class, %args) = @_;

    my $log = BBSConnectionGateway::Log::Logger->new(name => $class);

    my $config_file = $args{config} // "$Bin/../config.ini";

    # TODO : give option to pass section instead of package name
    my $package = $args{package} // "_"; #default to root level section
    $package =~ s/^.*::|\s*$//g; # don't care about namespace, just package name

    my $config_last_modified = (stat($config_file))[9] or confess "Cannot stat config file: $config_file :: $!";

    my $config = Config::Tiny->read($config_file)->{$package};
    confess "Failed to read config file: $config_file :: " . $Config::Tiny::errstr if ($Config::Tiny::errstr);

    $log->info("Built config for $package");

    my $self = {
        package_name => $package,
        config_last_modified => $config_last_modified,
        config_file => $config_file,
        config => $config,
        log => $log,
        section => $package,
    };

    return bless($self, $class);
}

sub _log {
    return shift->{log};
}

sub _config {
    my ($self, $new_config) = @_;
    if ($new_config) {
        $self->{config} = $new_config;
    }
    return $self->{config};
}

=head2 refresh_config
    Checks to see if the current configuration file has changed
    since the last configuration check. If it has, it will
    reload the contents of the config file

    returns true if config was refreshed.
=cut
sub refresh_config {
    my ($self) = @_;
    my $current_last_mod = (stat($self->{config_file}))[9];
    if (!$current_last_mod) {
        $self->_log->fatal("Failed to stat current config file: " . $self->{config_file} . " :: Using cached values!");
        return;
    }

    if ($current_last_mod > $self->{config_last_modified}) {
        $self->_log->warn("Configuration has been updated! Reloading config for: [" . $self->{package_name} . "] :: PREV=" . $self->{config_last_modified} . " :: CURRENT=$current_last_mod");
        $self->{config_last_modified} = $current_last_mod;
        $self->_config(Config::Tiny->read($self->{config_file})->{$self->{package_name}});
        confess "Failed to read config file: " . $self->{config_file} . " :: " . $Config::Tiny::errstr if ($Config::Tiny::errstr);
        return 1;
    }
    return;

}

sub _section {
    return shift->{section};
}

=head2 get
    Gets a config from the config file for a given section and key. Sections are
    decided by callers __PACKAGE__ name set in constructor. Environment variables
    override any values set in config file.

    Env variable format is "PACKAGENAME_CONFIG_KEY" (all uppercase);

    Args:
        config_key - config value to get from the package's section
        default (optional) - default value to use (default default is "")
=cut
sub get {
    my ($self, $config_key, $default_value) = @_;
    $config_key //= confess "Missing config key call to get_config";
    $default_value //= "";

    # check if env var is set up and if so, use that instead.
    my $env_var = uc($self->_section . "_" . $config_key);
    if (exists $ENV{$env_var}) {
        if ($ENV{$env_var} !~ m/^\s*$/) {
            $self->_log->warn("Using environment variable: $env_var for config: " . $self->_section . " :: $config_key");
            return $ENV{$env_var};
        }
    }
    $self->refresh_config;
    return $self->_config->{$config_key} // $default_value;
}

1;
