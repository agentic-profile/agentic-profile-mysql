import {
    OkPacket,
    Pool
} from "mysql2/promise";
import { createPool } from "./mysql-pool.js";
export { createPool };

let connectionPool: Pool;

export function pool(): Pool {
    if( !connectionPool )
        connectionPool = createPool();
    return connectionPool;
}

export async function queryResult( sql: string, params?: any[] ) {
    const [ result ] = await pool().query( sql, params );
    return result as OkPacket;
}

export async function queryRows<T>( sql: string, params?: any[] ) {
    const [ result ] = await pool().query( sql, params );
    return result as T[];
}

export async function queryFirstRow<T>( sql: string, params: any[] ) {
    let rows = await queryRows( sql, params );
    return rows.length > 0 ? rows[0] as T: null;
}

export function setOfRowColumnValues( rows: any[], columnName: string ) {
    let set = new Set<any>();
    for( let i = 0; i < rows.length; i++ )
        set.add( rows[i][columnName] );
    return Array.from(set.values());
}

export async function updateDB( sql: string, params: any[], failureMessage: string ) {
    const { affectedRows } = await queryResult( sql, params );
    if( affectedRows < 1 )
        throw new Error( failureMessage );    
}