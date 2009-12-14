#!/usr/bin/perl
# 
# example.pl
# 
# Author(s): Pablo Fischer (pfischer@cpan.org)
# Created: 12/13/2009 15:20:43 PST 15:20:43

use strict;
use warnings;
use Data::Dumper;
use AI::ExpertSystem::Complex;
use AI::ExpertSystem::Complex::KnowledgeDB::Factory;

my $yaml_kdb = AI::ExpertSystem::Complex::KnowledgeDB::Factory->new('yaml',
        {
            filename => 'examples/knowledge_db_one.yaml'
            });

my $ai = AI::ExpertSystem::Complex->new(
        viewer_class => 'terminal',
        knowledge_db => $yaml_kdb,
        initial_facts => ['L', 'I']);
$ai->backward();
$ai->summary();



