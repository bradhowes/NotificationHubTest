# -*- Mode: Python; tab-width: 4 -*-
#
# General log emission class
#

import array, os, string, sys, time, traceback, __main__

#
# Detect 1.4 vs 1.5 frame access
#
if hasattr( sys, 'exc_info' ):
	def _tb():
		return sys.exc_info()[ 2 ].tb_frame
else:
	def _tb():
		return sys.exc_traceback.tb_frame

_kTypeString = type( '' )

#
# Logger -- general routines for submitting information to a log - syslog or 
# file.
#
class Logger:

    kLevelMap = { 'fatal': 0,
                  'error': 1,
                  'warning': 2,
                  'info': 3,
                  'verbose': 4,
                  'debug': 5 }

	#
	# Define entry and exit tags used by LogProcEntry and LogProcExit
	#
	kEntryTag = 'BEG'
	kExitTag =  'END'

	#
	# Default output to nothing.
	#
	def __init__( self ):
        for name, level in self.kLevelMap.items():
            setattr( self, 'k' + string.capitalize( name ), level )

		self._out = self._flush = self._close = self._nothing
		self.fd = None					# File name or descriptor logging to
		self.showTime = 1				# If TRUE, print timestamp
		self.showThread = 0				# If TRUE, print thread ID
		self.showFile = 1				# If TRUE, print defining file name
		self.showFunc = 1				# If TRUE, print function name
		self.showSelf = 1				# If TRUE, print first method arg
		self.maxLength = None
		self.setLevel( self.kError )

	#
	# If logging to a file, close it and reopen it. Used for rolling log files.
	#
	def reset( self ):
		if type( self.fd ) == type( '' ):
			self.useFile( self.fd, self.showTime, self.showThread,
						  self.showFile )

	def _log( self, level, logMsg ):
		self._out( logMsg )
		self._flush()

	def _fatal( self, *args ):
		self._log( self.kFatal, self._formatOutput( self.kFatal, args ) )
	def _error( self, *args ):
		self._log( self.kError, self._formatOutput( self.kError, args ) )
	def _warning( self, *args ):
		self._log( self.kWarning, self._formatOutput( self.kWarning, args ) )
	def _info( self, *args ):
		self._log( self.kInfo, self._formatOutput( self.kInfo, args ) )
	def _verbose( self, *args ):
		self._log( self.kVerbose, self._formatOutput( self.kVerbose, args ) )
	def _debug( self, *args ):
		self._log( self.kDebug, self._formatOutput( self.kDebug, args ) )
	def _begin( self, *args ):
		self._log( self.kVerbose, self._formatOutput( self.kVerbose, args,
                                                      self.kEntryTag ) )
	def _end( self, *args ):
		self._log( self.kVerbose, self._formatOutput( self.kVerbose, args,
                                                      self.kExitTag ) )

	#
	# Issues a log message at the given severity level.
	#
	def log( self, level, *args ):
		self._log( level, self._formatOutput( level, args ) )

	#
	# Does not log anything
	#
	def _nothing( self, *ignored ):
		return

	#
	# Set the log threshold level. For faster processing, update methods to
	# either emit something or return silently.
	#
	def setLevel( self, maxLevel ):
		if type( maxLevel ) == _kTypeString:
			tmp = self.kLevels.get( string.lower( maxLevel ) )
            if tmp is None:
				raise ValueError, maxLevel
            maxLevel = tmp
 
		if maxLevel > self.kDebug:
			maxLevel = self.kDebug
		elif maxLevel < self.kFatal:
			maxLevel = self.kFatal

		#
		# Turn on/off levels
		#
		procs = self.__class__.__dict__
        for name, level in self.kLevelMap.items():
            if level <= maxLevel:
                setattr( self, name, getattr( self, '_' + name )  )
            else:
                setattr( self, name, self._nothing )

		#
		# Special handling for entry/exit methods.
		#
		if maxLevel >= self.kVerbose:
			self.begin = self._begin
			self.end = self._end
		else:
			self.begin = self.end = self._nothing

	#
	# Flush any pending output and revert to doing nothing
	#
	def close( self ):
		self._flush()
		self._close()
		self._out = self._flush = self._close = self._nothing

	#
	# Setup to use the given file object for log writing
	#
	def useFile( self, fd, showTime = 1, showThread = 0, showFile = 1 ):  
		self.close()
		self.fd = fd
		if type( fd ) == _kTypeString:
			fd = open( fd, 'w+' )
			self._close = fd.close		# Only close file desc. we open
		self._out = fd.write
		self._flush = fd.flush
		self.showTime = showTime
		self.showThread = showThread
		self.showFile = showFile

	#
	# Setup to use Python syslog module.
	#
	def useSyslog( self, ident, opts, facility, showTime = 0, showThread = 0,
				   showFile = 1 ):
		import syslog
		self.close()
		syslog.openlog( ident, opts, facility )
		self._out = syslog.syslog
		self._close = syslog.closelog
		self.showTime = showTime
		self.showThread = showThread
		self.showFile = showFile

	#
	# Setup to use whatever is set in sys.stderr.
	#
	def useStdErr( self, showTime = 1, showThread = 0, showFile = 1 ):  
		self.useFile( sys.stderr, showTime, showThread, showFile )

	#
	# Setup to use whatever is set in sys.stdout.
	#
	def useStdOut( self, showTime = 1, showThread = 0, showFile = 1 ):  
		self.useFile( sys.stdout, showTime, showThread, showFile )

	#
	# Set flag that determines if timestamp is printed in output.
	#
	def showTime( self, showTime = 1 ):
		self.showTime = showTime
 
	#
	# Set flag that determines if thread ID is printed in output.
	#
	def showThread( self, showThread = 1 ):
		self.showThread = showThread

	#
	# Set flag that determines if filename that contains the log statement is
	# printed.
	#
	def showFile( self, showFile = 1 ):
		self.showFile = showFile

	#
	# set flag that determines if function name is printed in output.
	#
	def showFunction( self, showFunc = 1 ):
		self.showFunc = showFunc
 
	#
	# Set flag that determines if the first argument (self) of a method is
	# printed in Begin() output.
	#
	def showSelf( self, showSelf = 1 ):
		self.showSelf = showSelf

	#
	# Internal function that builds the string that is ultimately sent to the
	# current sink device.
	#
	def _formatOutput( self, level, args, tag = "" ):

		#
		# Try to get context information. Looking for the name of the file we
		# are in, the name of the function (with possible class name
		# prepended), and if we are formatting a Begin() call, a list of
		# argnames and values that describe what is being passed into the
		# function we are logging.
		#
		doBegin = tag == self.kEntryTag and len( args ) == 0
		file, proc, bArgs = self._procInfo( doBegin )
		if len( bArgs ) > 0:
			args = bArgs
 
		#
		# Use arrays to build up message string in place. Should be faster than
		# string manipulations.
		#
		s = array.array( 'c' )

		#
		# Generate timestamp
		#
		if self.showTime:
			now = time.time()
			now = time.strftime( "%Y%m%d.%H%M%S", time.localtime( now ) )
			s.fromstring( now )
			s.append( ' ' )

		#
		# Generate thread ID
		#
		if self.showThread:
			from thread import get_ident
			s.append( '#' )
			s.fromstring( str( get_ident() ) )
			s.append( ' ' )

		#
		# Print file name containing the log statement
		#
		if self.showFile:
			s.fromstring( file )
			s.append( ' ' )

		#
		# Print the function name containing the log statement. May also have a
		# class name if this is a method.
		#
		if self.showFunc:
			s.fromstring( proc )
			s.append( ' ' )

		#
		# Print BEG/END tag
		#
		if len( tag ) > 0:
			s.fromstring( tag )
			s.append( ' ' )

		#
		# Append each argument to message string
		#
		for each in args:
			if type( each ) is _kTypeString:
				s.fromstring( each )
			else:
				s.fromstring( repr( each ) )
			s.append( ' ' )

		#
		# Finally, append a newline
		#
		s.append( '\n' )

		#
		# Return string representation of array
		#
		return s.tostring()

	#
	# Return the name of the class that defines the function being logged. We
	# walk the class hierarchy just like Python does in order to locate the
	# actual defining class.
	#
	def _definingClass( self, theClass, codeObj ):
		dict = theClass.__dict__
		name = codeObj.co_name
		if dict.has_key( name ):
			tmp = dict[ name ]
			if tmp.func_code == codeObj:
				return theClass.__name__
		for eachClass in theClass.__bases__:
			name = self._definingClass( eachClass, codeObj )
			if name != None:
				return name
		return None

	#
	# Returns a tuple containing information about the function being logged:
	# file name, caller name, argument list
	#
	def _procInfo( self, genArgs = 0 ):

		#
		# Obtain a frame object from the runtime interpreter.
		#
		frame = None
		try:
			raise RuntimeError
		except RuntimeError:
			frame = _tb()

		#
		# Setup default values
		#
		fileName = '__main__'
		procName = '?'
		args = []

		#
		# Work back to (hopefully) the calling frame.
		#
		if frame:
			frame = frame.f_back
			if frame:
				frame = frame.f_back
				if frame:
					frame = frame.f_back
 
		if frame:

			#
			# Extract the code object that contains the call to our log method.
			#
			code = frame.f_code
			fileName = os.path.split( code.co_filename )[ 1 ]
			procName = code.co_name
			numArgs = code.co_argcount
			if numArgs > 0:
				
				#
				# Assume we will display first argument. If we determine that
				# we are logging a method, obey the setting for showSelf.
				#
				firstArg = 0
 
				#
				# Get first argument and see if it is an object (ala self)
				#
				locals = frame.f_locals
				varNames = code.co_varnames
				obj = locals[ varNames[ 0 ] ]
				if type( obj ) == type( self ):
 
					#
					# Locate the class that defines the method being logged.
					#
					className = self._definingClass( obj.__class__, code )
					if className:
 
						#
						# Got it. See if we ignore the self argument when
						# printing.
						#
						procName = className + '.' + procName
						if not self.showSelf:
							firstArg = 1
 
				#
				# Create a list of argument names and their runtime values.
				# Only done if we are in a Begin() log method.
				#
				if genArgs:
					for each in varNames[ firstArg : numArgs ]:
						value = locals[ each ]
						if type( value ) == _kTypeString:
							arg = each + ': ' + value
						else:
							arg = each + ': ' + repr( value )
						args.append( arg )
					each = None

		obj = locals = None
		frame = code = None
		return ( fileName, procName, args )
 
def test():
	def a():
		gLog.begin()
		gLog.debug( 'this is a test' )
		gLog.end()
	a()

def DelLog():
	delattr( __main__.__builtins__, 'gLog' )

#
# First time we are imported, install a global variable `gLog' for everyone to
# see and use. By default, use stderr.
#
gLog = None
if not hasattr( __main__.__builtins__, 'gLog' ):
	gLog = Logger()
	__main__.__builtins__.gLog = gLog
	gLog.useStdErr()
else:
	gLog = __main__.builtins__.gLog
