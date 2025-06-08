import mysql, { Pool } from 'mysql2/promise'

export function createPool(): Pool {
    const {
        MYSQL_HOSTNAME: host,
        MYSQL_DATABASE: database,
        MYSQL_PASSWORD: password,
        MYSQL_USER: user
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
        connectionLimit : 10,   // TODO is there a better number?
        host,
        user,
        database, 
        port     : resolvePort(),
        timezone : '+00:00',
        charset  : 'utf8mb4',
        password : ''
    };

    console.log( new Date(), 'Creating MySQL2 pool with', JSON.stringify(options,null,4));
    options.password = password!;

    return mysql.createPool(options);
}

function resolvePort() {
    return parseInt(process.env.MYSQL_PORT || '3306');
}