package BBSConnectionGateway::Template::TemplateRenderer;

use v5.34;

use Carp;
use Config::Tiny;
use Exporter qw(import);
use FindBin qw($Bin);

use BBSConnectionGateway::Configuration::Config;
use BBSConnectionGateway::Log::Logger;

use constant {
    BUSY_TEMPLATE => 'busy_screen',
    OFFLINE_TEMPLATE => 'offline_screen',
    CONNECT_TEMPLATE => 'connect_screen',
    MAX_CONNECTIONS_TEMPLATE => 'max_connections',

    RENDER_MODE_FILE => 'FILE',
    RENDER_MODE_MSG => 'MSG',
    RENDER_MODE_ALL => 'ALL',
    RENDER_MODE_NONE => 'NONE',
};

our @EXPORT_OK = qw(
    BUSY_TEMPLATE
    OFFLINE_TEMPLATE
    CONNECT_TEMPLATE
    MAX_CONNECTIONS_TEMPLATE
);


sub new {
    my ($class, %args) = @_;

    my $log = BBSConnectionGateway::Log::Logger->new(name => $class);
    my $config = BBSConnectionGateway::Configuration::Config->new(package => __PACKAGE__);
    my @valid_templates = (BUSY_TEMPLATE, OFFLINE_TEMPLATE, CONNECT_TEMPLATE);

    my $self = {
        config => $config,
        log => $log,
        valid_templates => \@valid_templates,
    };


    return bless($self, $class);
}


sub _log {
    return shift->{log};
}


sub _config {
    return shift->{config};
}


sub _valid_templates {
    return shift->{valid_templates};
}


sub _render_mode {
    my ($self, $is_refresh) = @_;
    if (!defined $self->{render_mode} || $is_refresh) {
        my $new_render_mode = uc($self->_config->get('render_mode', RENDER_MODE_FILE));
        my @valid_render_modes = (RENDER_MODE_FILE, RENDER_MODE_MSG, RENDER_MODE_ALL, RENDER_MODE_NONE);
        if (!grep(/^\Q$new_render_mode\E$/, @valid_render_modes)) {
            $self->_log->error("Invalid render mode configured: $new_render_mode :: Valid modes: [" . join(',', @valid_render_modes) . "] :: Defaulting to mode: " . RENDER_MODE_FILE);
            $new_render_mode = RENDER_MODE_FILE;
        }
        $self->{render_mode} = $new_render_mode;
    }
    return $self->{render_mode} // RENDER_MODE_FILE;
}


sub _template_cache {
    my ($self, $is_refresh) = @_;

    if (!defined $self->{template_cache} || $is_refresh) {

        # Populate template file cache for modes that send the template files.

        my %template_cache;
        foreach my $template_type ($self->_valid_templates->@*) {
            my @temp_template_data;
            my $file = $self->_config->get($template_type . '_file', '');
            if (! -e $file) {
                $self->_log->error("Template file was not found for template: $template_type!");
                next;
            }

            open(my $FH, "<", $file) or do {
                $self->_log->fatal("Missing or error reading: $file ! :: $!");
                next;
            };

            @temp_template_data = <$FH>;
            close($FH);

            $template_cache{$template_type} = \@temp_template_data;
        }
        $self->{template_cache} = \%template_cache;
    }
    return shift->{template_cache} // { };
}


sub refresh_config {
    my ($self) = @_;
    $self->_config->refresh_config;
    $self->_render_mode(1);
    $self->_template_cache(1);
    return;
}


sub render {
    my ($self, $client, $template_type) = @_;

    $self->_log->info("Rendering template: $template_type");

    return if ($self->_render_mode eq RENDER_MODE_NONE);

    if (!grep(/^\Q$template_type\E$/, $self->_valid_templates->@*)) {
        $self->_log->fatal("Invalid template type: $template_type :: Sending client error message");
        $client->send("Sorry, an error has occurred.");
        return;
    }

    my $msg = $self->_config->get($template_type . '_msg', 'Sorry! An error has occurred');

    if ($self->_render_mode eq RENDER_MODE_MSG) {
        $client->send($msg);
        return;
    }

    my $template_data = $self->_template_cache->{$template_type} // [];
    my $is_send_msg = ($self->_render_mode eq RENDER_MODE_ALL || !scalar $template_data->@*) ? 1 : 0;

    $client->send($_) foreach ($template_data->@*);
    $client->send($msg) if ($is_send_msg);

    return;
}



1;
