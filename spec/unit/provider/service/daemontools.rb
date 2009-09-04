#!/usr/bin/env ruby
#
# Unit testing for the Daemontools service Provider
#
# author Brice Figureau
#
require File.dirname(__FILE__) + '/../../../spec_helper'

provider_class = Puppet::Type.type(:service).provider(:daemontools)

describe provider_class do

    before(:each) do
        # Create a mock resource
        @resource = stub 'resource'

        @provider = provider_class.new
        @servicedir = "/etc/service"
        @provider.servicedir=@servicedir
        @daemondir = "/var/lib/service"
        @provider.class.defpath=@daemondir

        # A catch all; no parameters set
        @resource.stubs(:[]).returns(nil)

        # But set name, source and path (because we won't run
        # the thing that will fetch the resource path from the provider)
        @resource.stubs(:[]).with(:name).returns "myservice"
        @resource.stubs(:[]).with(:ensure).returns :enabled
        @resource.stubs(:[]).with(:path).returns @daemondir
        @resource.stubs(:ref).returns "Service[myservice]"

        @provider.resource = @resource

        @provider.stubs(:command).with(:svc).returns "svc"
        @provider.stubs(:command).with(:svstat).returns "svstat"

        @provider.stubs(:svc)
        @provider.stubs(:svstat)
    end

    it "should have a restart method" do
        @provider.should respond_to(:restart)
    end

    it "should have a start method" do
        @provider.should respond_to(:start)
    end

    it "should have a stop method" do
        @provider.should respond_to(:stop)
    end

    it "should have an enabled? method" do
        @provider.should respond_to(:enabled?)
    end

    it "should have an enable method" do
        @provider.should respond_to(:enable)
    end

    it "should have a disable method" do
        @provider.should respond_to(:disable)
    end

    describe "when starting" do
        it "should use 'svc' to start the service" do
            @provider.stubs(:enabled?).returns true
            @provider.expects(:svc).with("-u", "/etc/service/myservice")

            @provider.start
        end

        it "should enable the service if it is not enabled" do
            @provider.stubs(:svc)

            @provider.expects(:enabled?).returns false
            @provider.expects(:enable)

            @provider.start
        end
    end

    describe "when stopping" do
        it "should use 'svc' to stop the service" do
            @provider.stubs(:disable)
            @provider.expects(:svc).with("-d", "/etc/service/myservice")

            @provider.stop
        end
    end

    describe "when restarting" do
        it "should use 'svc' to restart the service" do
            @provider.expects(:svc).with("-t", "/etc/service/myservice")

            @provider.restart
        end
    end

    describe "when enabling" do
        it "should create a symlink between daemon dir and service dir" do
            FileTest.stubs(:symlink?).returns(false)
            File.expects(:symlink).with(File.join(@daemondir,"myservice"), File.join(@servicedir,"myservice")).returns(0)
            @provider.enable
        end
    end

    describe "when disabling" do
        it "should remove the symlink between daemon dir and service dir" do
            FileTest.stubs(:directory?).returns(false)
            FileTest.stubs(:symlink?).returns(true)
            File.expects(:unlink).with(File.join(@servicedir,"myservice"))
            @provider.stubs(:texecute).returns("")
            @provider.disable
        end

        it "should stop the service" do
            FileTest.stubs(:directory?).returns(false)
            FileTest.stubs(:symlink?).returns(true)
            File.stubs(:unlink)
            @provider.expects(:stop)
            @provider.disable
        end
    end

    describe "when checking status" do
        it "should call the external command 'svstat /etc/service/myservice'" do
            @provider.expects(:svstat).with(File.join(@servicedir,"myservice"))
            @provider.status
        end
    end

    describe "when checking status" do
        it "and svstat fails, properly raise a Puppet::Error" do
            @provider.expects(:svstat).with(File.join(@servicedir,"myservice")).raises(Puppet::ExecutionFailure, "failure")
            lambda { @provider.status }.should raise_error(Puppet::Error, 'Could not get status for service Service[myservice]: failure')
        end
        it "and svstat returns up, then return :running" do
            @provider.expects(:svstat).with(File.join(@servicedir,"myservice")).returns("/etc/service/myservice: up (pid 454) 954326 seconds")
            @provider.status.should == :running
        end
        it "and svstat returns not running, then return :stopped" do
            @provider.expects(:svstat).with(File.join(@servicedir,"myservice")).returns("/etc/service/myservice: supervise not running")
            @provider.status.should  == :stopped
        end
    end

 end
