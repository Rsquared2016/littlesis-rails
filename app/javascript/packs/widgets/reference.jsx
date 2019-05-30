import React from 'react';
import PropTypes from 'prop-types';
import ReactDOM from 'react-dom';


export const NewReferenceForm = () => {
  return <p>New Reference Form</p>;
};


export const createNewReference = (id) => {
  ReactDOM.render(
    <NewReferenceForm />,
    document.getElementById(id)
  );
};
