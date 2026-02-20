import mysql, { Pool } from 'mysql2/promise'

export function createPool(): Pool {
    const {
        MYSQL_HOSTNAME: host,
        MYSQL_DATABASE: database,
        MYSQL_PASSWORD: password,
        MYSQL_USER: user,
        MYSQL_MAX_IDLE: maxIdle = 2,
        MYSQL_CONNECTION_LIMIT: connectionLimit = 20,
        MYSQL_IDLE_TIMEOUT: idleTimeout = 10000
    } = process.env;

    if( !host )
        console.error( "ERROR: process.env missing MYSQL_HOSTNAME" );
    if( !password )
        console.error( "ERROR: process.env missing MYSQL_PASSWORD" );
    if( !user )
        console.error( "ERROR: process.env missing MYSQL_USER" );
    if( !database )
        console.error( "ERROR: process.env missing MYSQL_DATABASE" );

    var options = {
        host,
        user,
        database, 
        port     : resolvePort(),
        timezone : '+00:00',
        charset  : 'utf8mb4',
        password : '',
        connectionLimit: Number(connectionLimit),
        maxIdle: Number(maxIdle),
        idleTimeout: Number(idleTimeout)
    };

    console.log( new Date(), 'Creating MySQL2 pool with', JSON.stringify(options,null,4));
    options.password = password!;

    const pool = mysql.createPool(options);
    
    // Set max listeners to prevent warnings
    pool.setMaxListeners(50);
        
    pool.on('connection', (connection) => {
        // Set max listeners on individual connections to prevent warnings
        // mysql2 adds internal 'wakeup' listeners that can accumulate
        connection.setMaxListeners(100);

        logConnectionStatus( pool, 'connection' );

        connection.on('error', (err) => {
            console.error('MySQL connection error:', err);
        });
    });

    pool.on('acquire', function (connection) {
        logConnectionStatus( pool, `acquire ${connection.threadId}` );
        //console.log('Connection %d acquired', connection.threadId);
    });

    pool.on('enqueue', function () {
        logConnectionStatus( pool, 'enqueue' );
        //console.log('Waiting for available connection slot');
    });

    pool.on('release', function (connection) {
        logConnectionStatus( pool, `release ${connection.threadId}` );
        //console.log('Connection %d released', connection.threadId);
    });

    return pool;
}

function resolvePort() {
    return parseInt(process.env.MYSQL_PORT || '3306');
}

const MYSQL_LOGGING = Boolean(process.env.MYSQL_LOGGING);

function logConnectionStatus( pool: Pool, message: string ) {

    if( !MYSQL_LOGGING )
        return;

    const { _allConnections, _freeConnections, _connectionQueue } = (pool as any)?.pool ?? {};
    console.log( 'MySQL', message, {
        allConnections: _allConnections?.length,
        freeConnections: _freeConnections?.length,
        connectionQueue: _connectionQueue?.length
    });
}