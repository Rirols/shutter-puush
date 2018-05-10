#! /usr/bin/env perl
###################################################
#
#  Copyright (C) <year> <author> <<email>>
#
#  This file is part of Shutter.
#
#  Shutter is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  Shutter is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with Shutter; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
###################################################
 
package puush;
 
use lib $ENV{'SHUTTER_ROOT'}.'/share/shutter/resources/modules';
 
use utf8;
use strict;
use POSIX qw/setlocale/;
use Locale::gettext;
use Glib qw/TRUE FALSE/;
use Data::Dumper;
 
use Shutter::Upload::Shared;
our @ISA = qw(Shutter::Upload::Shared);
 
my $d = Locale::gettext->domain("shutter-upload-plugins");
$d->dir( $ENV{'SHUTTER_INTL'} );
 
my %upload_plugin_info = (
    'module'                        => "puush",
    'url'                           => "https://puush.me/",
    'registration'                  => "https://puush.me/register",
    'name'                          => "puush",
    'description'                   => "Upload screenshots to puush",
    'supports_anonymous_upload'     => FALSE,
    'supports_authorized_upload'    => TRUE,
    'supports_oauth_upload'         => FALSE,
);
 
binmode( STDOUT, ":utf8" );
if ( exists $upload_plugin_info{$ARGV[ 0 ]} ) {
    print $upload_plugin_info{$ARGV[ 0 ]};
    exit;
}
 
 
#don't touch this
sub new {
    my $class = shift;
 
    #call constructor of super class (host, debug_cparam, shutter_root, gettext_object, main_gtk_window, ua)
    my $self = $class->SUPER::new( shift, shift, shift, shift, shift, shift );
 
    bless $self, $class;
    return $self;
}
 
#load some custom modules here (or do other custom stuff)   
sub init {
    my $self = shift;
 
    use LWP::UserAgent;
    use HTTP::Request::Common;
     
    return TRUE;
}
 
#handle 
sub upload {
    my ( $self, $upload_filename, $username, $password ) = @_;
 
    #store as object vars
    $self->{_filename} = $upload_filename;
    $self->{_username} = $username;
    $self->{_password} = $password;
 
    utf8::encode $upload_filename;
    utf8::encode $password;
    utf8::encode $username;
 
    my $browser = LWP::UserAgent->new(
        'timeout'    => 20,
        'keep_alive' => 10,
        'env_proxy'  => 1,
    );
     
    #username/password are provided
    if ( $username ne "" && $password ne "" ) {
 
        eval{
 
            ########################
            #put the login code here
            ########################

            my @params = (
                'https://puush.me/api/auth',
                'Content_Type' => 'application/x-www-form-urlencoded',
                'Content' => [
                    'e' => $username,
                    'p' => $password
                ]
            );

            my $req = POST(@params);
            my $rsp = $browser->request($req);

            my $login = $rsp->content == '-1' ? 'failure' : 'success';
            if ($login == 'success') {
                my ($premium, $apikey, $expire, $size_sum) = split /,/, $rsp->content;
                $self->{_apikey} = $apikey;
            }

            #if login failed (status code == 999) => Shutter will display an appropriate message
            unless ($login == 'success') {
               $self->{_links}{'status'} = 999;
               return;
            }
 
        };
        if($@){
            $self->{_links}{'status'} = $@;
            return %{ $self->{_links} };
        }
        if($self->{_links}{'status'} == 999){
            return %{ $self->{_links} };
        }
         
    }
     
    #upload the file
    eval{
 
        #########################
        #put the upload code here
        #########################

        my @params = (
            'https://puush.me/api/up',
            'Content_Type' => 'multipart/form-data',
            'Content' => [
                'k' => $self->{_apikey},
                'z' => 'poop',
                'f' => [$upload_filename],
            ]
        );

        my $req = POST(@params);
        my $rsp = $browser->request($req);

        if ($rsp->content == '-1' || $rsp->content == '-2') {
            $self->{_links}{'status'} = 'Upload failed';
        }
        else {
            my ($status, $url, $id, $size) = split /,/, $rsp->content;
            $self->{_links}->{'link'} = $url;

            #set success code (200)
            $self->{_links}{'status'} = 200;
        }
         
    };
    if($@){
        $self->{_links}{'status'} = $@;
    }
     
    #and return links
    return %{ $self->{_links} };
}
 
1;
