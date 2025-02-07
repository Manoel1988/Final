import React from 'react';
import { Link } from 'react-router-dom';
import { Package, Building2, Users } from 'lucide-react';

export function Settings() {
  return (
    <div className="p-6">
      <h1 className="text-2xl font-semibold text-gray-800 mb-6">Configurações</h1>
      
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Link 
          to="/settings/products"
          className="bg-white p-6 rounded-lg shadow-sm hover:shadow-md transition-shadow border border-gray-100"
        >
          <div className="flex items-center gap-4">
            <div className="p-3 bg-blue-50 rounded-lg">
              <Package className="w-6 h-6 text-blue-600" />
            </div>
            <div>
              <h3 className="text-lg font-medium text-gray-900">Produtos</h3>
              <p className="text-sm text-gray-500">Gerenciar produtos do sistema</p>
            </div>
          </div>
        </Link>

        <Link 
          to="/settings/company-status"
          className="bg-white p-6 rounded-lg shadow-sm hover:shadow-md transition-shadow border border-gray-100"
        >
          <div className="flex items-center gap-4">
            <div className="p-3 bg-green-50 rounded-lg">
              <Building2 className="w-6 h-6 text-green-600" />
            </div>
            <div>
              <h3 className="text-lg font-medium text-gray-900">Status de Empresa</h3>
              <p className="text-sm text-gray-500">Configurar status das empresas</p>
            </div>
          </div>
        </Link>

        <Link 
          to="/settings/roles"
          className="bg-white p-6 rounded-lg shadow-sm hover:shadow-md transition-shadow border border-gray-100"
        >
          <div className="flex items-center gap-4">
            <div className="p-3 bg-purple-50 rounded-lg">
              <Users className="w-6 h-6 text-purple-600" />
            </div>
            <div>
              <h3 className="text-lg font-medium text-gray-900">Cargos</h3>
              <p className="text-sm text-gray-500">Gerenciar cargos e permissões</p>
            </div>
          </div>
        </Link>
      </div>
    </div>
  );
}